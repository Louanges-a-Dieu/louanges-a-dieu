# Recette sur appareils réels (tâches 10.1, 10.2)

À exécuter sur **un iPhone, un Android et une tablette**, avec le build de staging puis celui
de production. Noter pour chaque appareil : modèle, version du système, version de l'app.

| Appareil | Système | App | Testeur | Date |
|---|---|---|---|---|
| | | | | |

## Cahier de recette (cahier des charges §T)

| Test | Scénario | Attendu | iPhone | Android | Tablette |
|---|---|---|---|---|---|
| T-001 | Installer, ouvrir sans compte | Recueil complet consultable, aucune connexion demandée | | | |
| T-002 | Chercher « 37 », « 37bis », « 37 bis » | Numéro exact en premier, « bis » trouvé | | | |
| T-003 | Chercher quelques mots de paroles, sans accents | Cantique trouvé, vers affiché | | | |
| T-004 | Mode avion (voir ci-dessous) | Tout fonctionne | | | |
| T-005 | Favori hors ligne, puis réseau rétabli avec compte | Favori conservé puis synchronisé | | | |
| T-006 | Programme de culte : créer, ordonner, annoter | Retrouvé tel quel, aussi sur un 2ᵉ appareil | | | |
| T-007 | Partager le programme, ouvrir le lien sur un autre téléphone | Page lisible ; lien désactivé → « Programme indisponible » | | | |
| T-008 | Projeter (point d'accès du téléphone → ordinateur) | Diapositive change en < 0,5 s, sans rechargement ; reprise après coupure | | | |
| T-009 | Corriger un cantique publié dans le back-office | Les apps gardent l'ancienne version jusqu'à la nouvelle publication | | | |
| T-010 | Ouvrir des cantiques sans auteur ni thème | Aucun champ vide ni « inconnu » affiché | | | |

Écoute (dès qu'un enregistrement est publié et `AUDIO_BASE_URL` configurée) :

| Test | Scénario | Attendu | iPhone | Android | Tablette |
|---|---|---|---|---|---|
| A-1 | Écouter, puis verrouiller l'écran | La lecture continue ; titre, version et commandes sur l'écran verrouillé | | | |
| A-2 | App en arrière-plan (autre app ouverte) | La lecture continue ; notification avec lecture/pause (Android) | | | |
| A-3 | Bouton du casque / des écouteurs | Lecture et pause | | | |
| A-4 | Téléphone en mode silencieux | L'enregistrement reste audible | | | |
| A-5 | Télécharger, passer en mode avion, écouter | Lecture complète sans réseau | | | |
| A-6 | Plus → Hors connexion → Supprimer les enregistrements | Place libérée ; « Télécharger » réapparaît | | | |
| A-7 | Quitter l'écran d'écoute | La lecture s'arrête, la notification disparaît | | | |
| A-8 | Karaoké d'un cantique synchronisé | Le vers chanté suit la voix (écart < ½ s), se remplit ligne après ligne ; toucher un vers y va ; « Écoute normale » ne coupe pas | | | |
| A-9 | Karaoké : passage instrumental marqué (P) | Le dernier vers s'éteint, « Reprise dans N s » jusqu'au couplet suivant | | | |

Accessibilité (5.10) : VoiceOver / TalkBack sur l'accueil, la recherche, une fiche (numéro
« 37 bis » lu correctement, refrain annoncé), le mode lecture ; texte système agrandi au maximum.

## Protocole mode avion (T-004)

1. Désinstaller l'app ; **couper** Wi-Fi et données (mode avion) ; installer depuis le build
   déjà téléchargé (TestFlight/Play : téléchargement préalable, puis mode avion).
2. Première ouverture : le recueil embarqué s'affiche ; aucune erreur.
3. Recherche numéro et paroles ; lecture ; mode lecture (écran allumé) ; favori.
4. Programme de culte (avec compte connecté auparavant) : création hors ligne, puis réseau
   rétabli → synchronisé.
5. Projection : point d'accès du téléphone **sans données mobiles** → ordinateur connecté →
   projection complète.

Automatisé (déjà vert) : tests de synchronisation hors ligne (Phase 4), instantané embarqué,
projection dans un vrai navigateur sans aucune requête externe, ordinateur seul avec serveur
arrêté et réseau coupé.

## Rapport

Consigner les résultats dans `docs/qa/rapport-<date>.md` (copie de ce tableau complété,
captures des anomalies).
