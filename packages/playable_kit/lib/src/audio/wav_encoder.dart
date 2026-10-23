import 'dart:typed_data';

import 'pcm_buffer.dart';

const int _headerBytes = 44;
const int _channels = 1;
const int _bitsPerSample = 16;
const int _bytesPerSample = _bitsPerSample ~/ 8;
const int _pcmFormatTag = 1;
const int _fmtChunkBytes = 16;

const double _fullScale = 32767.0;

Uint8List encodeWavMono16(PcmBuffer buffer) {
  final frames = buffer.frameCount;
  final dataBytes = frames * _channels * _bytesPerSample;
  final bytes = Uint8List(_headerBytes + dataBytes);
  final view = ByteData.view(bytes.buffer);

  _writeAscii(bytes, 0, 'RIFF');
  view.setUint32(4, _headerBytes - 8 + dataBytes, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');

  _writeAscii(bytes, 12, 'fmt ');
  view.setUint32(16, _fmtChunkBytes, Endian.little);
  view.setUint16(20, _pcmFormatTag, Endian.little);
  view.setUint16(22, _channels, Endian.little);
  view.setUint32(24, buffer.sampleRate, Endian.little);
  view.setUint32(
    28,
    buffer.sampleRate * _channels * _bytesPerSample,
    Endian.little,
  );
  view.setUint16(32, _channels * _bytesPerSample, Endian.little);
  view.setUint16(34, _bitsPerSample, Endian.little);

  _writeAscii(bytes, 36, 'data');
  view.setUint32(40, dataBytes, Endian.little);

  final samples = buffer.samples;
  var offset = _headerBytes;
  for (var i = 0; i < frames; i++) {
    var value = samples[i];
    if (value > 1.0) {
      value = 1.0;
    } else if (value < -1.0) {
      value = -1.0;
    }
    view.setInt16(offset, (value * _fullScale).round(), Endian.little);
    offset += _bytesPerSample;
  }

  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    bytes[offset + i] = text.codeUnitAt(i);
  }
}
