# dictd_reader

A Dart package for reading DICTD dictionary files (`.index` and `.dict`/`.dict.dz`).

## Features

- Parse DICTD `.index` files to get word offsets and lengths.
- Read definitions from `.dict` files using random access.
- Support for compressed `.dict.dz` files (using native `gzip` on supported platforms or pre-decompression).
- No external dependencies (uses native Dart `dart:io` and `dart:convert`).

## Getting started

Add `dictd_reader` to your `pubspec.yaml`:

```yaml
dependencies:
  dictd_reader: ^0.1.0
```

## Usage

### Parsing an Index File

```dart
import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  final parser = DictdParser();
  await for (final entry in parser.parseIndex('path/to/dictionary.index')) {
    print('Word: ${entry['word']}, Offset: ${entry['offset']}, Length: ${entry['length']}');
  }
}
```

### Reading a Definition

```dart
import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  final reader = DictdReader('path/to/dictionary.dict');
  await reader.open();
  
  final definition = await reader.readAtOffset(1234, 567);
  print(definition);
  
  await reader.close();
}
```

### Handling Compressed Files

```dart
import 'package:dictd_reader/dictd_reader.dart';

void main() async {
  final parser = DictdParser();
  final dictPath = await parser.maybeDecompressDictZ('path/to/dictionary.dict.dz');
  
  final reader = DictdReader(dictPath);
  // ... read definitions ...
}
```

## License

This project is licensed under the GNU GPLv3 License - see the [LICENSE](LICENSE) file for details.
