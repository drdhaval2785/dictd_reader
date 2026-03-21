## 0.1.2

- Add `RandomAccessSource` abstraction for SAF support.
- Allow `DictdReader` to open from a custom source via `openSource()`.

## 0.1.1

- Added `readEntries` to `DictdReader` for efficient batch reading of definitions.

## 0.1.0

- Initial release.
- Support for DICTD `.index` and `.index.gz` parsing.
- Support for random access reading of `.dict` and `.dict.dz` (dictzip) files.
- In-situ reading of compressed files using `dictzip_reader`.
- Pure Dart implementation, no Flutter dependency.
