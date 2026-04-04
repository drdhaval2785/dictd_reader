import 'dart:io';
import 'dart:typed_data';

abstract class RandomAccessSource {
  Future<Uint8List> read(int offset, int length);
  Future<int> get length;
  Future<void> close();
  Future<void> open();
}

class FileRandomAccessSource implements RandomAccessSource {
  final String path;
  RandomAccessFile? _file;
  int? _cachedLength;

  FileRandomAccessSource(this.path);

  Future<void> _ensureOpen() async {
    if (_file == null) {
      _file = await File(path).open(mode: FileMode.read);
      _cachedLength = await _file!.length();
    }
  }

  @override
  Future<void> open() async {
    await _ensureOpen();
  }

  @override
  Future<int> get length async {
    await _ensureOpen();
    return _cachedLength!;
  }

  @override
  Future<Uint8List> read(int offset, int length) async {
    await _ensureOpen();
    await _file!.setPosition(offset);
    return await _file!.read(length);
  }

  @override
  Future<void> close() async {
    await _file?.close();
    _file = null;
  }
}
