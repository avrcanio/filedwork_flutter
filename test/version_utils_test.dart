import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_flutter/core/app_update/version_utils.dart';

void main() {
  group('compareSemver', () {
    test('equal versions', () {
      expect(compareSemver('1.0.5', '1.0.5'), 0);
      expect(compareSemver('1.0.5+6', '1.0.5'), 0);
    });

    test('older patch', () {
      expect(isVersionOlder('1.0.4', '1.0.5'), isTrue);
      expect(isVersionOlder('1.0.5', '1.0.4'), isFalse);
    });

    test('older minor', () {
      expect(isVersionOlder('1.0.9', '1.1.0'), isTrue);
    });
  });
}
