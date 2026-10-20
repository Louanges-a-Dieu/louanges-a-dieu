import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/env.dart';

void main() {
  group('Env.parse', () {
    test('accepte une configuration dev sans backend', () {
      final env = Env.parse(const {'APP_ENV': 'dev'});
      expect(env.environment, AppEnvironment.dev);
      expect(env.hasBackend, isFalse);
    });

    test('écoute : sans adresse des enregistrements, indisponible', () {
      expect(Env.parse(const {'APP_ENV': 'dev'}).hasAudio, isFalse);
    });

    test('écoute : adresse en HTTPS, clé jointe sans « / » double', () {
      final env = Env.parse(const {
        'APP_ENV': 'dev',
        'AUDIO_BASE_URL': 'https://f003.backblazeb2.com/file/lad-audio/',
      });
      expect(env.hasAudio, isTrue);
      expect(
        env.audioUrl('cantiques/0037bis/melodie.mp3').toString(),
        'https://f003.backblazeb2.com/file/lad-audio/cantiques/0037bis/melodie.mp3',
      );
      expect(
        () => Env.parse(const {
          'APP_ENV': 'dev',
          'AUDIO_BASE_URL': 'http://exemple.test/audio',
        }),
        throwsFormatException,
      );
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
        'PUBLIC_WEB_URL': 'https://louanges.exemple.org/',
      });
      expect(env.environment, AppEnvironment.prod);
      expect(
        env.sharedProgramUrl('abc'),
        'https://louanges.exemple.org/programme/abc',
      );
      expect(env.hasBackend, isTrue);
    });

    test('exige PUBLIC_WEB_URL en HTTPS hors dev', () {
      expect(
        () => Env.parse(const {
          'APP_ENV': 'prod',
          'SUPABASE_URL': 'https://exemple.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'cle-publishable',
          'PUBLIC_WEB_URL': 'http://louanges.exemple.org',
        }),
        throwsFormatException,
      );
    });
  });
}
