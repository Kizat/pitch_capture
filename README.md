# pitch_capture

Flutter plugin for microphone capture with pitch detection utilities.

## Safer streaming API

`Capture.start(...)` remains available, but `Capture.audioStream(...)` is the
better fit for app-side state management. It starts capture on listen, stops it
on cancel, and ignores late native callbacks after cancellation.

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
    .listen((result) {
      debugPrint('pitch: ${result.pitch}');
    });

await subscription.cancel();
```
