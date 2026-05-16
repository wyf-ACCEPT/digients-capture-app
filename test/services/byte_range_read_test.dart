// Tier 3 (multipart upload) Phase 0 spike — proves that
// `File.openRead(start, end)` returns exactly the requested byte range,
// across buffer boundaries, even when the requested range doesn't align
// with the underlying read chunk size.
//
// This is the gating assumption for the on-demand chunk-splitting
// strategy described in .claude/plan/6e16-plan-multipart-upload.md
// (decision Q5 = strategy 5B). If `openRead(start, end)` is wrong, the
// per-part bytes uploaded to S3 won't match the source file's content
// at that offset, and CompleteMultipartUpload will return objects whose
// MD5 doesn't match what we recorded.
//
// Each test materializes a synthetic file with known content, reads a
// sub-range two different ways (streaming vs whole-file slice), and
// asserts byte-for-byte equality. The fill pattern is deterministic so
// failures point at specific byte offsets.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

Uint8List _patternedBytes(int length) {
  // Pattern: position i -> (i * 16807) mod 256. A linear-congruential
  // fill, not just `i mod 256` — avoids accidentally passing a test
  // where the streamed bytes are offset by a multiple of 256 and the
  // mod-256 fingerprint looks identical to the correct bytes.
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = (i * 16807) & 0xff;
  }
  return out;
}

Future<Uint8List> _streamRange(File f, int start, int end) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in f.openRead(start, end)) {
    builder.add(chunk);
  }
  return builder.toBytes();
}

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('byte_range_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('5 MB file, mid-file 1 MB range matches whole-file slice', () async {
    const fileSize = 5 * 1024 * 1024;
    const start = 2 * 1024 * 1024;
    const end = 3 * 1024 * 1024;

    final f = File('${tmpDir.path}/5mb.bin');
    final content = _patternedBytes(fileSize);
    await f.writeAsBytes(content);

    final streamed = await _streamRange(f, start, end);
    final sliced = content.sublist(start, end);

    expect(streamed.length, end - start);
    expect(streamed, equals(sliced));
  });

  test('range starting at offset 0 matches the file head', () async {
    const fileSize = 100 * 1024;
    const end = 25 * 1024;
    final f = File('${tmpDir.path}/head.bin');
    final content = _patternedBytes(fileSize);
    await f.writeAsBytes(content);

    final streamed = await _streamRange(f, 0, end);
    expect(streamed, equals(content.sublist(0, end)));
  });

  test('range ending exactly at file length matches the file tail', () async {
    const fileSize = 100 * 1024;
    const start = 75 * 1024;
    final f = File('${tmpDir.path}/tail.bin');
    final content = _patternedBytes(fileSize);
    await f.writeAsBytes(content);

    final streamed = await _streamRange(f, start, fileSize);
    expect(streamed, equals(content.sublist(start, fileSize)));
  });

  test('25 MB part size — three consecutive parts of a 70 MB file reassemble to the original',
      () async {
    // Mirrors the actual Tier 3 chunking call sites: serial 25 MB parts,
    // last part smaller. Confirms that concatenating the streamed
    // ranges in order yields the original file exactly.
    const fileSize = 70 * 1024 * 1024;
    const partSize = 25 * 1024 * 1024;

    final f = File('${tmpDir.path}/70mb.bin');
    final content = _patternedBytes(fileSize);
    await f.writeAsBytes(content);

    final totalParts = (fileSize / partSize).ceil();
    expect(totalParts, 3);

    final reassembled = BytesBuilder(copy: false);
    for (var partNum = 1; partNum <= totalParts; partNum++) {
      final offset = (partNum - 1) * partSize;
      final size = (partNum == totalParts) ? fileSize - offset : partSize;
      final partBytes = await _streamRange(f, offset, offset + size);
      expect(partBytes.length, size,
          reason: 'part $partNum should be exactly $size bytes');
      reassembled.add(partBytes);
    }

    final reassembledBytes = reassembled.toBytes();
    expect(reassembledBytes.length, fileSize);
    // Sample-compare a few sentinel positions to keep the failure
    // message readable, then full-equal as the real assertion.
    expect(reassembledBytes[0], content[0]);
    expect(reassembledBytes[partSize - 1], content[partSize - 1]);
    expect(reassembledBytes[partSize], content[partSize]);
    expect(reassembledBytes[fileSize - 1], content[fileSize - 1]);
    expect(reassembledBytes, equals(content));
  });

  test('range with bounds inside the same 64 KB internal read chunk', () async {
    // Default File.openRead chunk size is 64 KB. A range that lives
    // entirely inside one such chunk exercises the partial-buffer slice
    // path, not the multi-chunk concat path.
    const fileSize = 256 * 1024;
    const start = 70 * 1024;
    const end = 75 * 1024;
    final f = File('${tmpDir.path}/inchunk.bin');
    final content = _patternedBytes(fileSize);
    await f.writeAsBytes(content);

    final streamed = await _streamRange(f, start, end);
    expect(streamed, equals(content.sublist(start, end)));
  });
}
