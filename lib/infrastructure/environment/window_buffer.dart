import 'dart:math' as math;
import 'dart:typed_data';

/// Turns a stream of PCM16 chunks into fixed analysis windows.
///
/// 3-second windows with a 1-second hop, gated on loudness: near-silence is not
/// worth a model pass, and running the tagger on it drains the battery of a
/// device that is meant to keep listening all day.
///
/// Pure and synchronous, so the framing and the gate are unit-testable with no
/// microphone.
final class WindowBuffer {
  /// Creates a buffer.
  WindowBuffer({
    this.sampleRate = 16000,
    this.windowSeconds = 3,
    this.hopSeconds = 1,
    this.rmsGate = 0.008,
  }) : _window = sampleRate * windowSeconds,
       _hop = sampleRate * hopSeconds;

  /// Samples per second.
  final int sampleRate;

  /// How much audio the model sees at once.
  final int windowSeconds;

  /// How often a window is produced.
  final int hopSeconds;

  /// Root-mean-square below which a window is dropped as silence.
  final double rmsGate;

  final int _window;
  final int _hop;
  final List<double> _samples = <double>[];

  int _sinceLastWindow = 0;
  bool _hasEmitted = false;

  /// How many samples are buffered.
  int get bufferedSamples => _samples.length;

  /// Adds PCM16 little-endian [chunk] and returns any windows it completed.
  ///
  /// Windows quieter than [rmsGate] are dropped here rather than downstream, so
  /// the classifier only ever sees audio worth classifying.
  List<Float32List> add(Uint8List chunk) {
    final ByteData view = ByteData.sublistView(chunk);
    final int count = chunk.lengthInBytes ~/ 2;
    for (int i = 0; i < count; i++) {
      _samples.add(view.getInt16(i * 2, Endian.little) / 32768.0);
    }
    _sinceLastWindow += count;

    // At most one window per call: only the newest `windowSeconds` of audio is
    // retained, so there is no earlier window left to emit. A chunk larger than
    // the hop does not produce duplicates of the same slice.
    final List<Float32List> windows = <Float32List>[];
    final bool due = !_hasEmitted || _sinceLastWindow >= _hop;
    if (_samples.length >= _window && due) {
      final Float32List window = Float32List.fromList(
        _samples.sublist(_samples.length - _window),
      );
      _sinceLastWindow = 0;
      _hasEmitted = true;
      if (rms(window) >= rmsGate) windows.add(window);
    }

    // Keep only what the next window needs.
    if (_samples.length > _window) {
      _samples.removeRange(0, _samples.length - _window);
    }
    return windows;
  }

  /// Discards everything buffered.
  void reset() {
    _samples.clear();
    _sinceLastWindow = 0;
    _hasEmitted = false;
  }

  /// Root mean square of [samples], in `0..1`.
  static double rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    double sum = 0;
    for (final double sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }
}
