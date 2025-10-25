import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parity test sentinel', () {
    // Simple existence checks only; avoid heavy directory ops to reduce crash risk.
    final required = [
      'test/distance_parity_test.dart',
      'test/stops_parity_test.dart',
      'test/time_parity_test.dart',
    ];
    for (final path in required) {
      expect(File(path).existsSync(), true, reason: 'Missing parity file: $path');
    }
  });
}
