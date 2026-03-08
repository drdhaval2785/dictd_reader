import 'package:test/test.dart';
import 'package:dictd_reader/dictd_reader.dart';

void main() {
  group('DictdReader Batch Read', () {
    const dictPath = 'test/data/test.dictd';

    test('readEntries reads correct content in order', () async {
      final reader = DictdReader(dictPath);
      await reader.open();

      final entries = [
        (offset: 0, length: 5), // hello
        (offset: 5, length: 5), // world
      ];

      final results = await reader.readEntries(entries);
      expect(results, ['hello', 'world']);

      await reader.close();
    });

    test('readEntries handles out-of-order input and returns results in original order', () async {
      final reader = DictdReader(dictPath);
      await reader.open();

      final entries = [
        (offset: 5, length: 5), // world
        (offset: 0, length: 5), // hello
      ];

      final results = await reader.readEntries(entries);
      expect(results, ['world', 'hello']);

      await reader.close();
    });

    test('readEntries handles empty list', () async {
      final reader = DictdReader(dictPath);
      await reader.open();
      final results = await reader.readEntries([]);
      expect(results, isEmpty);
      await reader.close();
    });
  });
}
