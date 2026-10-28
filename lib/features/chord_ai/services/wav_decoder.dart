import 'dart:typed_data';

/// Decodificador leve e nativo em Dart puro para arquivos de áudio WAV (RIFF/WAVE)
/// Permite processamento offline direto pelo RealtimeChordDetector sem depender de codecs nativos
class WavDecoder {
  /// Converte os bytes de um arquivo WAV em amostras PCM mono Float64List (-1.0 a 1.0)
  static Float64List? decodeToMonoPcm(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final ByteData bd = ByteData.sublistView(bytes);

    // Validação do cabeçalho "RIFF"
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
      return null;
    }
    // Validação do formato "WAVE"
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
      return null;
    }

    int offset = 12;
    int numChannels = 1;
    int sampleRate = 44100;
    int bitsPerSample = 16;
    int audioFormat = 1; // 1 = PCM, 3 = IEEE Float
    int dataOffset = -1;
    int dataSize = 0;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (chunkId == 'fmt ') {
        audioFormat = bd.getUint16(offset, Endian.little);
        numChannels = bd.getUint16(offset + 2, Endian.little);
        sampleRate = bd.getUint32(offset + 4, Endian.little);
        bitsPerSample = bd.getUint16(offset + 14, Endian.little);
        offset += chunkSize;
      } else if (chunkId == 'data') {
        dataOffset = offset;
        dataSize = chunkSize;
        break;
      } else {
        offset += chunkSize;
      }
    }

    if (dataOffset == -1 || dataOffset >= bytes.length) {
      return null;
    }

    if (dataOffset + dataSize > bytes.length) {
      dataSize = bytes.length - dataOffset;
    }

    final int bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample <= 0 || numChannels <= 0) return null;

    final int totalFrames = dataSize ~/ (bytesPerSample * numChannels);
    if (totalFrames <= 0) return null;

    final result = Float64List(totalFrames);
    int curOffset = dataOffset;

    for (int i = 0; i < totalFrames; i++) {
      double sumChannel = 0.0;
      for (int ch = 0; ch < numChannels; ch++) {
        double val = 0.0;
        if (audioFormat == 1) {
          // PCM Inteiro
          if (bitsPerSample == 16) {
            val = bd.getInt16(curOffset, Endian.little) / 32768.0;
            curOffset += 2;
          } else if (bitsPerSample == 8) {
            val = (bd.getUint8(curOffset) - 128) / 128.0;
            curOffset += 1;
          } else if (bitsPerSample == 24) {
            final b0 = bd.getUint8(curOffset);
            final b1 = bd.getUint8(curOffset + 1);
            final b2 = bd.getInt8(curOffset + 2);
            final int24 = (b2 << 16) | (b1 << 8) | b0;
            val = int24 / 8388608.0;
            curOffset += 3;
          } else if (bitsPerSample == 32) {
            val = bd.getInt32(curOffset, Endian.little) / 2147483648.0;
            curOffset += 4;
          }
        } else if (audioFormat == 3) {
          // Ponto Flutuante IEEE 32-bit
          val = bd.getFloat32(curOffset, Endian.little).toDouble();
          curOffset += 4;
        }
        sumChannel += val;
      }
      result[i] = (sumChannel / numChannels).clamp(-1.0, 1.0);
    }

    return result;
  }
}
