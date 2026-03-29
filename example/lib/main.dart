import 'package:flutter/material.dart';
import 'dart:async';

import 'package:pitch_capture/capture.dart';
import 'package:pitch_capture/pitch_detector/pitch_detector.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Capture _plugin = Capture();
  final PitchDetector _pitchDetector = PitchDetector(
    audioSampleRate: 16000,
    bufferSize: 3000,
  );
  StreamSubscription? _pitchSubscription;

  @override
  void initState() {
    super.initState();
    // Need to initialize before use note that this is async!
    _plugin.init();
  }

  Future<void> _startCapture() async {
    await _pitchSubscription?.cancel();
    _pitchSubscription = _plugin
        .audioStream(sampleRate: 16000, bufferSize: 3000)
        .asyncMap(_pitchDetector.getPitchFromPCM16)
        .listen(listener, onError: onError);
  }

  Future<void> _stopCapture() async {
    await _pitchSubscription?.cancel();
    _pitchSubscription = null;
  }

  void listener(dynamic obj) {
    debugPrint('$obj');
  }

  void onError(Object e) {
    debugPrint('$e');
  }

  @override
  void dispose() {
    _pitchSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Audio Capture Plugin')),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: _startCapture,
                        child: Text("Start"),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: _stopCapture,
                        child: Text("Stop"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
