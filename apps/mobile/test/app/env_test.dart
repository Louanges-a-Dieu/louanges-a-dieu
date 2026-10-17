import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/env.dart';

void main() {
  group('Env.parse', () {
    test('accepte une configuration dev sans backend', () {
      final env = Env.parse(const {'APP_ENV': 'dev'});
      expect(env.environment, AppEnvironment.dev);
      expect(env.hasBackend, isFalse);
    });

    test('rejette un environnement inconnu', () {
      expect(
        () => Env.parse(const {'APP_ENV': 'production'}),
        throwsFormatException,
      );
    });

    test('exige HTTPS hors dev', () {
      expect(
        () => Env.parse(const {
          'APP_ENV': 'prod',
          'SUPABASE_URL': 'http://exemple.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'cle-publishable',
        }),
        throwsFormatException,
      );
    });

    test('exige la clé publique hors dev', () {
      expect(
        () => Env.parse(const {
          'APP_ENV': 'staging',
          'SUPABASE_URL': 'https://exemple.supabase.co',
        }),
        throwsFormatException,
      );
    });

    test('accepte une configuration prod complète', () {
      final env = Env.parse(const {
        'APP_ENV': 'prod',
        'SUPABASE_URL': 'https://exemple.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'cle-publishable',
      });
      expect(env.environment, AppEnvironment.prod);
      expect(env.hasBackend, isTrue);
    });
  });
}
