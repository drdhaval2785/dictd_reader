import 'dart:io';
import 'dart:math';
import 'package:dictd_reader/dictd_reader.dart';

Future<void> runBenchmark(DictdReader reader, int numEntries, int fileSize, Random random) async {
  final entries = List.generate(numEntries, (i) {
    final offset = random.nextInt(fileSize - 300);
    final length = 50 + random.nextInt(200);
    return (offset: offset, length: length);
  });

  print('\n--- Benchmarking $numEntries RANDOM reads ---');

  final stopwatch = Stopwatch()..start();
  for (final entry in entries) {
    await reader.readAtOffset(entry.offset, entry.length);
  }
  stopwatch.stop();
  final individualTime = stopwatch.elapsedMilliseconds;
  print('Individual reads: ${individualTime}ms');

  stopwatch.reset();
  stopwatch.start();
  await reader.readEntries(entries);
  stopwatch.stop();
  final batchTime = stopwatch.elapsedMilliseconds;
  print('Batch read (sorted): ${batchTime}ms');
  
  if (individualTime > 0) {
    final savings = ((individualTime - batchTime) / individualTime * 100).toStringAsFixed(1);
    print('Time savings: $savings%');
  }
}

void main() async {
  final dictPath = 'test/data/test.dictd';
  final file = File(dictPath);
  if (!await file.exists()) {
    print('Test data not found.');
    return;
  }
  
  final reader = DictdReader(dictPath);
  await reader.open();
  final fileSize = await file.length();
  final random = Random(42);

  // Warm up
  await reader.readAtOffset(0, 5);

  await runBenchmark(reader, 100, fileSize, random);

  await reader.close();
}
