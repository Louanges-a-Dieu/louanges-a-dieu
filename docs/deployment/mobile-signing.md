# Signature des applications mobiles (tâche 10.8)

Toutes les clés appartiennent au **propriétaire** et sont rangées dans le coffre de mots de
passe du projet (jamais dans le dépôt, jamais chez un seul développeur).

## Android — Play App Signing

Google conserve la **clé de signature** de l'application ; nous ne détenons que la **clé
d'envoi** (« upload key »), remplaçable si elle est perdue.

1. Créer la clé d'envoi (JDK `keytool`) :

   ```sh
   keytool -genkeypair -v -keystore louanges-upload.jks -alias upload \
     -keyalg RSA -keysize 4096 -validity 10000 \
     -dname "CN=Louanges a Dieu, O=Louanges a Dieu"
   ```

2. Ranger `louanges-upload.jks` et ses mots de passe dans le coffre.
3. Pour compiler, créer `apps/mobile/android/key.properties` (ignoré par Git) :

   ```properties
   storeFile=/chemin/vers/louanges-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

4. Compiler : `LAD_STORE_BUILD=true flutter build appbundle --release
   --dart-define-from-file=config/prod.json`. Sans `key.properties`, ce build **échoue**
   (`app/build.gradle.kts`) au lieu de produire un paquet signé avec la clé de débogage.
5. Play Console → créer l'application `org.louangesadieu.app` → accepter **Play App Signing**
   lors du premier envoi.
6. En CI (plus tard) : clé et mots de passe dans les secrets de l'environnement GitHub
   `production`, fichier reconstitué pendant le job puis effacé.

Perte de la clé d'envoi : Play Console → Intégrité de l'application → demander la
réinitialisation de la clé d'envoi (la clé de signature, détenue par Google, n'est pas perdue).

## iOS — App Store Connect

1. Compte Apple Developer **individuel** au nom du propriétaire (Q-17), adhésion annuelle.
2. Identifiant d'app `org.louangesadieu.app` (Certificates, Identifiers & Profiles).
3. Xcode → Runner → Signing & Capabilities : équipe du propriétaire, signature automatique.
4. **Clé API App Store Connect** (Users and Access → Integrations → App Store Connect API) :
   rôle « App Manager » ; télécharger le fichier `.p8` **une seule fois** et le ranger dans le
   coffre avec son « Key ID » et l'« Issuer ID ». Elle servira aux envois automatisés.
5. Envoi : `flutter build ipa --release --dart-define-from-file=config/prod.json`, puis
   Transporter ou `xcrun altool`.

## Inventaire (à reporter dans `docs/ownership/accounts.md`)

| Élément | Détenteur | Emplacement |
|---|---|---|
| Clé d'envoi Android + mots de passe | propriétaire | coffre |
| Clé de signature Android | Google (Play App Signing) | — |
| Certificats et profils iOS | compte Apple du propriétaire | Apple |
| Clé API App Store Connect (.p8, Key ID, Issuer ID) | propriétaire | coffre |
