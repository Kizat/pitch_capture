# pitch_capture

`pitch_capture` is a Flutter plugin for microphone capture with built-in pitch
detection utilities.

It provides two layers:

- `Capture`: low-level audio capture from the native microphone pipeline.
- `PitchDetector`: Dart-side pitch analysis for PCM audio buffers.

The package is useful for tuners, vocal practice apps, instrument training, and
other real-time audio analysis flows.

## Features

- Microphone audio capture on Android and iOS
- PCM16 audio buffer handling in Dart
- Pitch detection with a YIN-based algorithm
- Simple callback API with `Capture.start(...)`
- Safer stream-based API with `Capture.audioStream(...)`
- Protection against late native callbacks after `stop()`

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  pitch_capture: ^0.0.2
```

Then run:

```bash
flutter pub get
```

## Import

```dart
import 'package:pitch_capture/capture.dart';
import 'package:pitch_capture/pitch_detector/pitch_detector.dart';
```

## Quick Start

Initialize `Capture` before starting audio capture:

```dart
final capture = Capture();
await capture.init();
```

If initialization fails, `init()` returns `false`. If capture was never
initialized, `start()` throws.

## Capture API

`Capture` exposes two ways to consume microphone audio.

### 1. Callback API

This is the lower-level API. It works well if your app already has its own
streaming or queueing layer.

```dart
final capture = Capture();
await capture.init();

await capture.start(
  (pcm16Bytes) {
    // Uint8List PCM16 audio chunk
  },
  (error) {
    // handle capture error
  },
  sampleRate: 16000,
  bufferSize: 3000,
);

await capture.stop();
```

### 2. Stream API

This is the recommended API for most app code. It starts capture when listened
to and stops when the subscription is cancelled.

```dart
final capture = Capture();
await capture.init();

final subscription = capture
    .audioStream(sampleRate: 16000, bufferSize: 3000)
    .listen((pcm16Bytes) {
      // consume audio
    });

await subscription.cancel();
```

The stream API is usually the better fit for Bloc, Cubit, Rx, or plain Dart
stream transforms because it avoids manual `add(...)` calls from native
callbacks.

## Pitch Detection

Use `PitchDetector` to analyze audio buffers and obtain:

- `pitch`: detected pitch in Hz
- `probability`: confidence-like value from the detector
- `pitched`: whether a pitch was detected

Example:

```dart
final detector = PitchDetector(
  audioSampleRate: 16000,
  bufferSize: 3000,
);

final result = await detector.getPitchFromPCM16(pcm16Bytes);

if (result.pitched) {
  debugPrint('Pitch: ${result.pitch} Hz');
}
```

## Recommended End-to-End Example

This pattern is the safest integration for UI state management:

```dart
final capture = Capture();
await capture.init();

final detector = PitchDetector(
  audioSampleRate: 16000,
  bufferSize: 3000,
);

final subscription = capture
    .audioStream(sampleRate: 16000, bufferSize: 3000)
    .asyncMap(detector.getPitchFromPCM16)
    .listen(
      (result) {
        if (result.pitched) {
          debugPrint(
            'pitch=${result.pitch}, probability=${result.probability}',
          );
        }
      },
      onError: (error) {
        debugPrint('capture error: $error');
      },
    );

await subscription.cancel();
```

## Why `audioStream(...)` Is Safer

Native audio capture can still produce a late callback even after `stop()` has
been requested, especially when app-side code performs asynchronous work on each
buffer.

This package now guards against that by ignoring late events from older capture
sessions. Even so, the stream API is still the cleaner consumer model because:

- cancellation is explicit and local to the subscription
- async transforms compose naturally with `asyncMap`
- app code does not need to call `bloc.add(...)` from a native callback
- it reduces race-condition pressure in UI state layers

## Configuration

`Capture.start(...)` and `Capture.audioStream(...)` support these parameters:

- `sampleRate`: requested recording sample rate, default `44100`
- `bufferSize`: requested audio buffer size, default `4000`
- `fps`: optional frame rate hint, default `-1`
- `androidAudioSource`: Android audio source constant
- `firstDataTimeout`: timeout while waiting for the first audio frame
- `waitForFirstDataOnAndroid`: enabled by default
- `waitForFirstDataOnIOS`: disabled by default

Available Android audio source constants:

- `ANDROID_AUDIOSRC_DEFAULT`
- `ANDROID_AUDIOSRC_MIC`
- `ANDROID_AUDIOSRC_CAMCORDER`
- `ANDROID_AUDIOSRC_VOICERECOGNITION`
- `ANDROID_AUDIOSRC_VOICECOMMUNICATION`
- `ANDROID_AUDIOSRC_UNPROCESSED`

## Actual Sample Rate

The native layer may not always deliver exactly the requested sample rate.

You can inspect the last known actual sample rate with:

```dart
final actual = capture.actualSampleRate;
```

If accurate pitch tracking matters, prefer configuring `PitchDetector` with the
real sample rate used by the native capture path.

## Buffer Format

`Capture` delivers `Uint8List` PCM16 audio data.

`PitchDetector` can analyze:

- `getPitchFromPCM16(Uint8List pcm16Buffer)`
- `getPitchFromIntBuffer(Uint8List intPCM16AudioBuffer)`
- `getPitchFromFloatBuffer(List<double> floatPCM32AudioBuffer)`

The input buffer length must be at least the detector `bufferSize`, otherwise
`InvalidAudioBufferException` is thrown.

## Practical Notes

- Call `await capture.init()` before any start/listen operation.
- Keep `sampleRate` and `PitchDetector.audioSampleRate` aligned.
- Keep `bufferSize` consistent between capture and detection.
- For UI state management, prefer `audioStream(...).asyncMap(...)` over manual
  callback chaining.
- If you stop capture while async processing is still running, app-side code
  should still avoid updating already-disposed UI/state objects.

## Example App

See the example app here:

- [`example/lib/main.dart`](example/lib/main.dart)

## Platform Notes

- Android: waits for the first audio frame by default.
- iOS: waiting for the first frame is disabled by default because it is less
  reliable there.

## License

See [`LICENSE`](LICENSE).
