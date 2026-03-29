class PitchDetectorResult {
  double pitch;
  double probability;
  bool pitched;

  /// Pitch is the pitch value in Hz
  /// Probability is the probability of it being the given pitch
  /// pitched shows if the audioSample contains a pitch.
  PitchDetectorResult({
    required this.pitch,
    required this.probability,
    required this.pitched,
  });
}
