import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/infrastructure/environment/window_buffer.dart';

void main() {
  /// PCM16 little-endian bytes for [samples] seconds of a tone at [amplitude].
  Uint8List pcm(double seconds, {double amplitude = 0.5, int rate = 16000}) {
    final int count = (seconds * rate).round();
    final ByteData data = ByteData(count * 2);
    for (int i = 0; i < count; i++) {
      final double value = amplitude * math.sin(2 * math.pi * 440 * i / rate);
      data.setInt16(i * 2, (value * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  test('nothing is produced before a full window exists', () {
    final WindowBuffer buffer = WindowBuffer();
    expect(buffer.add(pcm(2)), isEmpty);
  });

  test('a full window is produced at three seconds', () {
    final WindowBuffer buffer = WindowBuffer();
    buffer.add(pcm(2));
    final List<Float32List> windows = buffer.add(pcm(1));

    expect(windows, hasLength(1));
    expect(windows.single.length, 16000 * 3);
  });

  test('windows arrive one second apart, not every chunk', () {
    final WindowBuffer buffer = WindowBuffer();
    buffer.add(pcm(3));
    // Half a second more should not produce a second window.
    expect(buffer.add(pcm(0.5)), isEmpty);
    expect(buffer.add(pcm(0.5)), hasLength(1));
  });

  test('near-silence is gated out before the model ever sees it', () {
    final WindowBuffer buffer = WindowBuffer();
    expect(buffer.add(pcm(3, amplitude: 0.0005)), isEmpty);
  });

  test('the gate lets ordinary sound through', () {
    final WindowBuffer buffer = WindowBuffer();
    expect(buffer.add(pcm(3, amplitude: 0.3)), hasLength(1));
  });

  test('samples are normalised into minus one to one', () {
    final WindowBuffer buffer = WindowBuffer();
    final Float32List window = buffer.add(pcm(3)).single;
    for (final double sample in window) {
      expect(sample, inInclusiveRange(-1.0, 1.0));
    }
  });

  test('the buffer does not grow without bound', () {
    final WindowBuffer buffer = WindowBuffer();
    for (int i = 0; i < 20; i++) {
      buffer.add(pcm(1));
    }
    expect(buffer.bufferedSamples, lessThanOrEqualTo(16000 * 3));
  });

  test('reset empties the buffer', () {
    final WindowBuffer buffer = WindowBuffer()..add(pcm(2));
    buffer.reset();
    expect(buffer.bufferedSamples, 0);
  });

  test('rms is zero for silence and positive for sound', () {
    expect(WindowBuffer.rms(Float32List(100)), 0);
    expect(
      WindowBuffer.rms(Float32List.fromList(<double>[0.5, -0.5, 0.5, -0.5])),
      closeTo(0.5, 0.001),
    );
  });
}
