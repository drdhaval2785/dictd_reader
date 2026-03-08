import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dictzip_reader/dictzip_reader.dart';

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
  /// Parses a DICTD `.index` file and yields map entries with:
  ///   - `word`: the headword string
  ///   - `offset`: byte offset in the `.dict` file (int)
  ///   - `length`: byte length of the definition (int)
  Stream<Map<String, dynamic>> parseIndex(String indexPath) async* {
    final file = File(indexPath);
    if (!await file.exists()) {
      throw FileSystemException('DICTD .index file not found', indexPath);
    }

    Stream<List<int>> byteStream = file.openRead();
    if (indexPath.endsWith('.gz')) {
      byteStream = byteStream.transform(gzip.decoder);
    }

    final lines = byteStream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
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
      } catch (e) {
        // Skip malformed entries
        continue;
      }
    }
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
  RandomAccessFile? _raf;
  DictzipReader? _dzReader;

  DictdReader(this.dictPath);

  bool get _isCompressed => dictPath.endsWith('.dz') || dictPath.endsWith('.gz');

  /// Opens the file for repeated random-access reads.
  Future<void> open() async {
    if (_isCompressed) {
      _dzReader = DictzipReader(dictPath);
      await _dzReader!.open();
    } else {
      _raf = await File(dictPath).open(mode: FileMode.read);
    }
  }

  /// Reads the definition at [offset] with [length] bytes.
  Future<String> readAtOffset(int offset, int length) async {
    if (_isCompressed) {
      if (_dzReader == null) throw StateError('DictdReader not opened.');
      return await _dzReader!.read(offset, length);
    } else {
      if (_raf == null) throw StateError('DictdReader not opened.');
      await _raf!.setPosition(offset);
      final bytes = await _raf!.read(length);
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// One-shot read without keeping the file open.
  Future<String> readEntry(int offset, int length) async {
    if (_isCompressed) {
      final reader = DictzipReader(dictPath);
      await reader.open();
      try {
        return await reader.read(offset, length);
      } finally {
        await reader.close();
      }
    } else {
      final raf = await File(dictPath).open(mode: FileMode.read);
      try {
        await raf.setPosition(offset);
        final bytes = await raf.read(length);
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await raf.close();
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
      final queries =
          entries.map((e) => (e.offset, e.length)).toList();
      return await _dzReader!.readBulk(queries);
    } else {
      if (_raf == null) throw StateError('DictdReader not opened.');

      // Keep track of original indices to return results in order
      final indexedEntries = entries.asMap().entries.toList();

      // Sort by offset for sequential access
      indexedEntries.sort((a, b) => a.value.offset.compareTo(b.value.offset));

      final results = List<String?>.filled(entries.length, null);

      for (final entry in indexedEntries) {
        await _raf!.setPosition(entry.value.offset);
        final bytes = await _raf!.read(entry.value.length);
        results[entry.key] = utf8.decode(bytes, allowMalformed: true);
      }
      return results.cast<String>();
    }
  }

  /// Closes the underlying file.
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
    await _dzReader?.close();
    _dzReader = null;
  }
}
