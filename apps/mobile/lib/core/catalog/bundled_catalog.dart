import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../sync/catalog_sync.dart';
import 'catalog_models.dart';
import 'gunzip.dart';

/// Instantané du catalogue embarqué dans l'application (ADR-005), généré au
/// build par `content-tools export-snapshot`. Absent des builds de développement
/// qui ne l'ont pas généré : l'app télécharge alors le catalogue au premier accès réseau.
class AssetBundledCatalogSource implements BundledCatalogSource {
  AssetBundledCatalogSource({AssetBundle? bundle, this.path = defaultPath})
    : _bundle = bundle ?? rootBundle;

  static const defaultPath = 'assets/catalog/catalog_snapshot.json.gz';

  final AssetBundle _bundle;
  final String path;

  @override
  Future<CatalogSnapshot?> load() async {
    if (!gunzipSupported) return null;
    final ByteData data;
    try {
      data = await _bundle.load(path);
    } on FlutterError {
      return null; // instantané non embarqué dans ce build
    }
    // Décompression et validation hors du fil d'affichage (~1 Mo de JSON).
    return compute(
      decodeSnapshot,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
}

/// gzip → JSON → instantané validé par le contrat.
CatalogSnapshot decodeSnapshot(Uint8List gzipped) {
  final json = jsonDecode(utf8.decode(gunzip(gzipped)));
  if (json is! Map<String, Object?>) {
    throw const FormatException('Instantané embarqué invalide');
  }
  return CatalogSnapshot.fromJson(json);
}
