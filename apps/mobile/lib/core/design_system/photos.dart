/// Photos embarquées utilisables comme illustration (programmes, écran
/// projeté). Registre des sources et licences : docs/ownership/assets.md.
const appPhotos = <String, String>{
  'hero_wheat_sunset': 'assets/images/hero_wheat_sunset.jpg',
  'banner_wheat_ears': 'assets/images/banner_wheat_ears.jpg',
};

/// Chemin d'une photo par son nom, ou null si elle n'existe pas (plus).
String? photoAsset(String? name) => name == null ? null : appPhotos[name];
