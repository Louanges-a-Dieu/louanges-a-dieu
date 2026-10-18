// Décompression gzip : native sur iOS/Android, indisponible dans l'aperçu web.
export 'gunzip_io.dart' if (dart.library.js_interop) 'gunzip_web.dart';
