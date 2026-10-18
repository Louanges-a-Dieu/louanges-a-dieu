import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ajoute les licences des polices embarquées à l'écran « Licences » de l'app.
void registerFontLicenses() {
  const fonts = {
    'Cormorant Garamond': 'assets/fonts/CormorantGaramond/OFL.txt',
    'Literata': 'assets/fonts/Literata/OFL.txt',
    'Inter': 'assets/fonts/Inter/OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in fonts.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}
