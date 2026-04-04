import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dictzip_reader/dictzip_reader.dart' as dz;
import 'source.dart';

/// Parser and Reader for the DICTD dictionary format.
///
/// A DICTD dictionary consists of:
///   - A `.index` file: a sorted tab-delimited text file, one line per entry:
///       `word\tbase64_offset\tbase64_length`
///     where offset/length are base64-encoded big-endian 32-bit integers
///     pointing into the `.dict` (or `.dict.dz`) file.
///   - A `.dict` file: plain UTF-8 text containing definitions.
///   - An optional `.dict.dz` file: the dict file compressed with dictzip
///     (a gzip variant with a seek table).
class DictdParser {
  /// Parses a DICTD `.index` file and yields map entries.
  Stream<Map<String, dynamic>> parseIndex(RandomAccessSource source) async* {
    final length = await source.length;
    final bytes = await source.read(0, length);

    // Decompress if needed (simple gzip check)
    Uint8List decompressedBytes = bytes;
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      decompressedBytes = Uint8List.fromList(gzip.decode(bytes));
    }

    yield* parseIndexFromBytes(decompressedBytes);
  }

  /// Parses a DICTD `.index` file from raw [bytes].
  Stream<Map<String, dynamic>> parseIndexFromBytes(Uint8List bytes) async* {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split('\t');
      if (parts.length < 3) continue;

      final word = parts[0];
      final offsetB64 = parts[1];
      final lengthB64 = parts[2];

      try {
        final offset = _decodeBase64Int(offsetB64);
        final length = _decodeBase64Int(lengthB64);
        yield {'word': word, 'offset': offset, 'length': length};
      } catch (_) {
        continue;
      }
    }
  }

  /// Decodes a DICTD base64-encoded integer.
  ///
  /// DICTD uses a custom base64 alphabet:
  ///   ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
  /// This is the standard RFC 4648 base64 — each character represents 6 bits
  /// of a big-endian integer. The integer is then the numeric offset/size.
  int _decodeBase64Int(String s) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    int result = 0;
    for (final char in s.split('')) {
      final idx = alphabet.indexOf(char);
      if (idx < 0) throw FormatException('Invalid base64 char: $char');
      result = result * 64 + idx;
    }
    return result;
  }
}

/// Reads definitions from a DICTD `.dict` or `.dict.dz` file using stored offsets/lengths.
class DictdReader {
  final String dictPath;
  RandomAccessSource? _source;
  dz.DictzipReader? _dzReader;

  DictdReader(this.dictPath);

  bool get _isCompressed =>
      dictPath.endsWith('.dz') || dictPath.endsWith('.gz');

  /// Opens the file for repeated random-access reads.
  Future<void> open() async {
    return openSource(FileRandomAccessSource(dictPath));
  }

  /// Opens the source for repeated random-access reads.
  Future<void> openSource(RandomAccessSource source) async {
    _source = source;
    await source.open();
    if (_isCompressed) {
      _dzReader = dz.DictzipReader(dictPath);
      await _dzReader!.openSource(source as dz.RandomAccessSource);
    }
  }

  /// Reads the definition at [offset] with [length] bytes.
  Future<String> readAtOffset(int offset, int length) async {
    if (_isCompressed) {
      if (_dzReader == null) throw StateError('DictdReader not opened.');
      return await _dzReader!.read(offset, length);
    } else {
      if (_source == null) throw StateError('DictdReader not opened.');
      final bytes = await _source!.read(offset, length);
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// One-shot read without keeping the file open.
  Future<String> readEntry(int offset, int length) async {
    if (_isCompressed) {
      final reader = dz.DictzipReader(dictPath);
      await reader.open();
      try {
        return await reader.read(offset, length);
      } finally {
        await reader.close();
      }
    } else {
      final source = FileRandomAccessSource(dictPath);
      try {
        await source.open();
        final bytes = await source.read(offset, length);
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await source.close();
      }
    }
  }

  /// Reads multiple definitions in one batch.
  /// [entries] is a list of objects with [offset] and [length].
  /// This optimizes reading by sorting and minimizing seeks.
  Future<List<String>> readEntries(
      List<({int offset, int length})> entries) async {
    if (entries.isEmpty) return [];

    if (_isCompressed) {
      if (_dzReader == null) throw StateError('DictdReader not opened.');
      final queries = entries.map((e) => (e.offset, e.length)).toList();
      return await _dzReader!.readBulk(queries);
    } else {
      if (_source == null) throw StateError('DictdReader not opened.');

      // Keep track of original indices to return results in order
      final indexedEntries = entries.asMap().entries.toList();

      // Sort by offset for potential sequential access optimization in the source
      indexedEntries.sort((a, b) => a.value.offset.compareTo(b.value.offset));

      final results = List<String?>.filled(entries.length, null);

      for (final entry in indexedEntries) {
        final bytes =
            await _source!.read(entry.value.offset, entry.value.length);
        results[entry.key] = utf8.decode(bytes, allowMalformed: true);
      }
      return results.cast<String>();
    }
  }

  /// Closes the underlying source.
  Future<void> close() async {
    await _source?.close();
    _source = null;
    await _dzReader?.close();
    _dzReader = null;
  }
}
