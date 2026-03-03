import 'package:test/test.dart';
import 'package:dictd_reader/dictd_reader.dart';

void main() {
  group('DictdParser', () {
    const indexPath = 'test/data/test.index';

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
  });

  group('DictdReader', () {
    const dictPath = 'test/data/test.dictd';

    test('readAtOffset reads correct content from plain file', () async {
      final reader = DictdReader(dictPath);
      await reader.open();

      final part1 = await reader.readAtOffset(0, 5);
      expect(part1, 'hello');

      final part2 = await reader.readAtOffset(5, 5);
      expect(part2, 'world');

      await reader.close();
    });

    test('readEntry reads without keeping file open from plain file', () async {
      final reader = DictdReader(dictPath);
      final content = await reader.readEntry(0, 5);
      expect(content, 'hello');
    });
  });
}
