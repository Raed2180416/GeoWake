import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Ensures parity tests remain present ( Phase 0 gate ).
void main() {
  test('parity_canary_presence', () {
    final dir = Directory('test');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.contains('projection_progress_parity_test'))
        .toList();
    expect(files.isNotEmpty, true, reason: 'Parity test file missing; Phase 0 guard failed');
  });
}
