import 'dart:io';
import 'package:test/test.dart';
import 'package:dictd_reader/dictd_reader.dart';

void main() {
  group('DictdParser', () {
    const indexPath = 'test/data/test.index';
    const dictPath = 'test/data/test.dictd';
    late String dictDzPath;

    setUpAll(() async {
      dictDzPath = 'test/data/test.dict.dz';
      // Create a gzipped version for testing decompression
      final dictBytes = File(dictPath).readAsBytesSync();
      final gzippedBytes = gzip.encode(dictBytes);
      File(dictDzPath).writeAsBytesSync(gzippedBytes);
    });

    tearDownAll(() async {
      // Remove only the generated .dz file, keep the base test files
      final dzFile = File(dictDzPath);
      if (dzFile.existsSync()) {
        dzFile.deleteSync();
      }
      // Also remove any decompressed file if it was created during manual testing
      final decompressed = File('test/data/test.dict');
      if (decompressed.existsSync()) {
        decompressed.deleteSync();
      }
    });

    test('parseIndex parses entries correctly', () async {
      final parser = DictdParser();
      final entries = await parser.parseIndex(indexPath).toList();

      expect(entries.length, 2);
      expect(entries[0]['word'], 'hello');
      expect(entries[0]['offset'], 0);
      expect(entries[0]['length'], 5);
      expect(entries[1]['word'], 'world');
      expect(entries[1]['offset'], 5);
      expect(entries[1]['length'], 5);
    });

    test('maybeDecompressDictZ decompresses correctly', () async {
      final parser = DictdParser();
      final decompressedPath = await parser.maybeDecompressDictZ(dictDzPath);

      expect(decompressedPath, 'test/data/test.dict');
      expect(File(decompressedPath).existsSync(), true);
      expect(File(decompressedPath).readAsStringSync(), 'helloworld');
    });
  });

  group('DictdReader', () {
    const dictPath = 'test/data/test.dictd';

    test('readAtOffset reads correct content', () async {
      final reader = DictdReader(dictPath);
      await reader.open();

      final part1 = await reader.readAtOffset(0, 5);
      expect(part1, 'hello');

      final part2 = await reader.readAtOffset(5, 5);
      expect(part2, 'world');

      await reader.close();
    });

    test('readEntry reads without keeping file open', () async {
      final reader = DictdReader(dictPath);
      final content = await reader.readEntry(0, 5);
      expect(content, 'hello');
    });
  });
}
