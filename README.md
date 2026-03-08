# dictd_reader

A Dart package for reading DICTD dictionary files (`.index` and `.dict`/`.dict.dz`).

## Features

- **Efficient Index Parsing**: Parse DICTD `.index` files to get word offsets and lengths.
- **Gzipped Index Support**: Automatically handles `.index.gz` files in-situ.
- **Random Access Reading**: Read definitions from `.dict` files efficiently.
- **In-situ Compressed Reading**: Full support for `.dict.dz` (dictzip) files without decompression, using the `dictzip_reader` package.
- **Lightweight**: Pure Dart implementation, no Flutter dependency.

## Getting started

Add `dictd_reader` to your `pubspec.yaml`:

```yaml
dependencies:
  dictd_reader: ^0.1.0
```

## Usage

### Parsing an Index File

The `DictdParser` can handle both plain `.index` and compressed `.index.gz` files.

```dart
import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  final parser = DictdParser();
  
  // Works with both .index and .index.gz
  await for (final entry in parser.parseIndex('path/to/dictionary.index.gz')) {
    print('Word: ${entry['word']}, Offset: ${entry['offset']}, Length: ${entry['length']}');
  }
}
```

### Reading a Definition

The `DictdReader` automatically detects if a file is compressed (`.dz` or `.gz`) and uses `dictzip_reader` for efficient random access if it is.

```dart
import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  // Works with .dict, .dict.dz, and .dict.gz
  final reader = DictdReader('path/to/dictionary.dict.dz');
  await reader.open();
  
  // Read definition at a specific offset and length (usually obtained from the index)
  final definition = await reader.readAtOffset(1234, 567);
  print(definition);
  
  await reader.close();
}
```

### Batch Reading

For improved performance when reading multiple definitions, use `readEntries`:

```dart
final entries = [
  (offset: 0, length: 5),
  (offset: 5, length: 5),
];
final definitions = await reader.readEntries(entries);
```

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE](LICENSE) file for details.

## Github

https://github.com/drdhaval2785/dictd_reader
