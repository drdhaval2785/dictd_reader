import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dictd_reader/dictd_reader.dart';

void main() {
  const dictPath = 'test/data/test.dictd';

  group('FileRandomAccessSource', () {
    test('reads data correctly', () async {
      final source = FileRandomAccessSource(dictPath);
      expect(await source.length, 10);

      final data = await source.read(0, 5);
      expect(String.fromCharCodes(data), 'hello');

      final data2 = await source.read(5, 5);
      expect(String.fromCharCodes(data2), 'world');

      await source.close();
    });
  });

  group('DictdReader with Custom Source', () {
    test('works with a mock source', () async {
      final mockSource = MockSource('mock data');
      final reader = DictdReader('mock.dict');
      await reader.openSource(mockSource);

      final content = await reader.readAtOffset(0, 4);
      expect(content, 'mock');

      final content2 = await reader.readAtOffset(5, 4);
      expect(content2, 'data');

      await reader.close();
    });

    test('readEntries works with custom source', () async {
      final mockSource = MockSource('0123456789');
      final reader = DictdReader('mock.dict');
      await reader.openSource(mockSource);

      final entries = [
        (offset: 0, length: 2),
        (offset: 4, length: 2),
      ];

      final results = await reader.readEntries(entries);
      expect(results, ['01', '45']);

      await reader.close();
    });
  });
}

class MockSource implements RandomAccessSource {
  final String data;
  MockSource(this.data);

  @override
  Future<void> open() async {}

  @override
  Future<int> get length async => data.length;

  @override
  Future<Uint8List> read(int offset, int length) async {
    return Uint8List.fromList(
        data.substring(offset, offset + length).codeUnits);
  }

  @override
  Future<void> close() async {}
}
