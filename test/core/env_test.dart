import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/env.dart';

void main() {
  group('Env.check', () {
    test('passes when every value is set', () {
      expect(() => Env.check({'A': 'x', 'B': 'y'}), returnsNormally);
    });

    test('lists every missing or blank key', () {
      expect(
        () => Env.check({'A': 'x', 'B': '', 'C': '  '}),
        throwsA(
          isA<MissingEnvError>().having((e) => e.keys, 'keys', ['B', 'C']),
        ),
      );
    });
  });
}
