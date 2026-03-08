import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  // Path to your DICTD .dict or .dict.dz file
  const dictPath = 'test/data/test.dictd';
  
  final reader = DictdReader(dictPath);
  
  // Always open the reader before use
  await reader.open();
  
  try {
    // Define the entries you want to read (offset, length)
    final entries = [
      (offset: 0, length: 5),
      (offset: 5, length: 5),
    ];
    
    // Read all entries in one batch efficiently
    final definitions = await reader.readEntries(entries);
    
    for (var i = 0; i < definitions.length; i++) {
      print('Definition ${i + 1}: ${definitions[i]}');
    }
  } finally {
    // Close the reader to free up resources
    await reader.close();
  }
}
