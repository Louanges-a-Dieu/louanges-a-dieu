/// Aperçu web (développement uniquement, Q-« option B ») : l'instantané
/// embarqué n'est pas utilisé, le catalogue est téléchargé depuis le serveur.
const bool gunzipSupported = false;

List<int> gunzip(List<int> bytes) =>
    throw UnsupportedError('Décompression gzip indisponible sur le web');
