import 'dart:typed_data';

import 'package:pitch_capture/pitch_detector/algorithm/pitch_algorithm.dart';
import 'package:pitch_capture/pitch_detector/algorithm/yin.dart';
import 'package:pitch_capture/pitch_detector/exceptions/invalid_audio_buffer_exception.dart';
import 'package:pitch_capture/pitch_detector/pitch_detector_result.dart';
import 'package:pitch_capture/pitch_detector/util/pcm_util_extensions.dart';

/// Pitch detector
///
/// Validates an audio sample and tries to find a pitch
class PitchDetector {
  // ignore: constant_identifier_names
  static const int DEFAULT_SAMPLE_RATE = 44100;
  // ignore: constant_identifier_names
  static const int DEFAULT_BUFFER_SIZE = 2048;

  double audioSampleRate;
  int bufferSize;
  final PitchAlgorithm _pitchAlgorithm;

  PitchDetector({
    this.audioSampleRate = DEFAULT_SAMPLE_RATE * 1.0,
    this.bufferSize = DEFAULT_BUFFER_SIZE,
  }) : _pitchAlgorithm = Yin(audioSampleRate, bufferSize);

  /// PCM16 enconding
  ///
  /// Most libraries return PCM16 as UInt8List. Use this method to find a pitch.
  Future<PitchDetectorResult> getPitchFromIntBuffer(
    final Uint8List intPCM16AudioBuffer,
  ) async {
    final floatBuffer = intPCM16AudioBuffer.convertPCM16ToFloat();

    return await getPitchFromFloatBuffer(floatBuffer);
  }

  /// PCMFloat enconding
  ///
  /// Use this method to find a pitch from a PCM float encoding. Audio sample size needs to match or be greater than the buffer size
  Future<PitchDetectorResult> getPitchFromFloatBuffer(
    final List<double> floatPCM32AudioBuffer,
  ) async {
    if (floatPCM32AudioBuffer.length < bufferSize) {
      throw InvalidAudioBufferException(
        floatPCM32AudioBuffer.length,
        bufferSize,
      );
    }

    return await _pitchAlgorithm.getPitch(floatPCM32AudioBuffer);
  }

  List<double> _pcm16ToDouble(Uint8List bytes) {
    final alignedBytes = Uint8List.fromList(bytes);
    final byteBuffer = alignedBytes.buffer;
    final int16List = byteBuffer.asInt16List(
      0,
      alignedBytes.lengthInBytes ~/ 2,
    );

    return int16List.map((s) => s / 32768.0).toList(); // нормализация
  }

  Future<PitchDetectorResult> getPitchFromPCM16(Uint8List pcm16Buffer) async {
    final floatBuffer = _pcm16ToDouble(pcm16Buffer);

    if (floatBuffer.length < bufferSize) {
      throw InvalidAudioBufferException(floatBuffer.length, bufferSize);
    }

    return await _pitchAlgorithm.getPitch(floatBuffer);
  }
}
