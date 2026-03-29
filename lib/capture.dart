// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const CAPTURE_EVENT_CHANNEL_NAME = "capture_event_channel";
const CAPTURE_METHOD_CHANNEL_NAME = "capture_method_channel";

const ANDROID_AUDIOSRC_DEFAULT = 0;
const ANDROID_AUDIOSRC_MIC = 1;
const ANDROID_AUDIOSRC_CAMCORDER = 5;
const ANDROID_AUDIOSRC_VOICERECOGNITION = 6;
const ANDROID_AUDIOSRC_VOICECOMMUNICATION = 7;
const ANDROID_AUDIOSRC_UNPROCESSED = 9;

class Capture {
  static const _audioCaptureEventChannel = EventChannel(
    CAPTURE_EVENT_CHANNEL_NAME,
  );

  // ignore: cancel_subscriptions
  StreamSubscription? _audioCaptureEventChannelSubscription;
  int _sessionId = 0;

  static const _audioCaptureMethodChannel = MethodChannel(
    CAPTURE_METHOD_CHANNEL_NAME,
  );

  double? _actualSampleRate;

  bool? _initialized;

  Future<bool?> init() async {
    // Only init once
    if (_initialized != null) return _initialized;
    _initialized = await _audioCaptureMethodChannel.invokeMethod<bool>("init");
    return _initialized;
  }

  /// Starts listenening to audio.
  ///
  /// Uses [sampleRate] and [bufferSize] for capturing audio.
  /// Uses [androidAudioSource] to determine recording type on Android.
  /// When [waitForFirstDataOnAndroid] is set, it waits for [firstDataTimeout] duration on first data to arrive.
  /// Will not listen if first date does not arrive in time. Set as [true] by default on Android.
  /// When [waitForFirstDataOnIOS] is set, it waits for [firstDataTimeout] duration on first data to arrive.
  /// Known to not work reliably on iOS and set as [false] by default.
  Future<void> start(
    void Function(Uint8List) listener,
    Function onError, {
    int sampleRate = 44100,
    int bufferSize = 4000,
    int fps = -1,
    int androidAudioSource = ANDROID_AUDIOSRC_DEFAULT,
    Duration firstDataTimeout = const Duration(seconds: 1),
    bool waitForFirstDataOnAndroid = true,
    bool waitForFirstDataOnIOS = false,
  }) async {
    if (_initialized == null) {
      throw Exception("Capture must be initialized before use");
    }

    if (_initialized == false) {
      throw Exception("Capture failed to initialize");
    }

    // We are already listening
    if (_audioCaptureEventChannelSubscription != null) return;
    // init channel stream
    final stream =
        _audioCaptureEventChannel.receiveBroadcastStream({
          "sampleRate": sampleRate,
          "bufferSize": bufferSize,
          "audioSource": androidAudioSource,
          "fps": fps,
        }).cast<Map>();
    // The channel will have format:
    // {
    //   "audioData": Float32List,
    //   "actualSampleRate": double,
    // }

    _actualSampleRate = null;
    final sessionId = ++_sessionId;
    var audioStream = stream.map((event) {
      _actualSampleRate = event.get('actualSampleRate');
      return event.get('audioData') as Uint8List;
    });

    // Do we need to wait for first data?
    final waitForFirstData =
        (Platform.isAndroid && waitForFirstDataOnAndroid) ||
        (Platform.isIOS && waitForFirstDataOnIOS);

    Completer<void>? completer = Completer();
    // Prevent stream for starting over because we have no listenre between firstWhere check and this line which initally was at the end of the code
    _audioCaptureEventChannelSubscription = audioStream
        .skipWhile((element) => !completer.isCompleted)
        .listen((data) {
          if (_sessionId != sessionId) return;
          listener(data);
        }, onError: (Object error, StackTrace stackTrace) {
          if (_sessionId != sessionId) return;
          onError(error);
        });
    if (waitForFirstData) {
      try {
        await audioStream
            .firstWhere((element) => (_actualSampleRate ?? 0) > 10)
            .timeout(firstDataTimeout);
      } catch (e) {
        // If we timeout, cancel the stream and throw error
        completer.completeError(e);
        await stop();
        rethrow;
      }
    }
    completer.complete();
  }

  Future<void> stop() async {
    if (_audioCaptureEventChannelSubscription == null) return;
    _sessionId++;
    final tempListener = _audioCaptureEventChannelSubscription;
    _audioCaptureEventChannelSubscription = null;
    await tempListener!.cancel();
  }

  double? get actualSampleRate => _actualSampleRate;

  /// Returns a stream that starts audio capture on listen and stops it on cancel.
  ///
  /// This API is safer for consumers that want to compose async transforms
  /// because cancellation closes the stream and ignores any late native events.
  Stream<Uint8List> audioStream({
    int sampleRate = 44100,
    int bufferSize = 4000,
    int fps = -1,
    int androidAudioSource = ANDROID_AUDIOSRC_DEFAULT,
    Duration firstDataTimeout = const Duration(seconds: 1),
    bool waitForFirstDataOnAndroid = true,
    bool waitForFirstDataOnIOS = false,
  }) {
    late final StreamController<Uint8List> controller;
    var cancelled = false;

    controller = StreamController<Uint8List>(
      onListen: () async {
        try {
          await start(
            (data) {
              if (cancelled || controller.isClosed) return;
              controller.add(data);
            },
            (Object error) {
              if (cancelled || controller.isClosed) return;
              controller.addError(error);
            },
            sampleRate: sampleRate,
            bufferSize: bufferSize,
            fps: fps,
            androidAudioSource: androidAudioSource,
            firstDataTimeout: firstDataTimeout,
            waitForFirstDataOnAndroid: waitForFirstDataOnAndroid,
            waitForFirstDataOnIOS: waitForFirstDataOnIOS,
          );
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
            await controller.close();
          }
        }
      },
      onCancel: () async {
        cancelled = true;
        await stop();
      },
    );

    return controller.stream;
  }
}

extension MapUtil on Map {
  T get<T>(String key) {
    return this[key]!;
  }

  T? getOrNull<T>(String key) {
    return this[key];
  }
}
