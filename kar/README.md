# KAR

Application personnelle de gestion scolaire : année académique, matières avec
coefficient et crédits, devoirs et examens, notes, programme de révision.

Interface et données entièrement en français.

## Plateformes

L'application cible le web (PWA installable, utilisable hors ligne) et Android.

La base de données SQLite passe par une abstraction de plateforme
(`lib/data/db_platform.dart`) qui choisit l'implémentation selon la
compilation :

| Plateforme | Fichier | Implémentation |
|---|---|---|
| Android / desktop | `db_platform_io.dart` | `sqflite` natif, base dans `getDatabasesPath()` |
| Web | `db_platform_web.dart` | `sqlite3` compilé en WebAssembly, persistance IndexedDB |

`web/sqlite3.wasm` est requis pour la version web et ne doit pas être supprimé.

## Prérequis

- Flutter 3.44.1 ou supérieur (Dart 3.12)
- Android : SDK Android + un JDK compatible avec le Gradle wrapper

## Commandes

```bash
flutter pub get

# Lancer en développement
flutter run -d chrome      # web
flutter run                # Android

# Tests et analyse statique
flutter test
flutter analyze

# Build web : génère un build utilisable hors ligne
tool\build_web.ps1

# Build Android
flutter build apk --debug
```

### Build web hors ligne

`tool\build_web.ps1` lance `flutter build web` avec `--no-web-resources-cdn`
pour embarquer CanvasKit localement, puis remplace le service worker généré par
Flutter (`flutter_service_worker.js`) par `web/service_worker.js`, qui sait mettre
en cache l'application, les polices et les variantes de CanvasKit pour un usage
déconnecté. Utiliser ce script plutôt que `flutter build web` directement.

### Icônes

Les icônes de la PWA et de l'écran de lancement Android sont générées par code,
elles ne sont pas versionnées comme assets Flutter :

```bash
dart run tool/generate_icons.dart
```

## Organisation

```
lib/
  data/       accès SQLite et abstraction de plateforme
  domain/     logique métier pure (calculs de moyennes)
  models/     classes de données (toMap / fromMap)
  screens/    écrans
  services/   cas d'usage au-dessus de la couche données
  state/      état global (thème)
  widgets/    composants réutilisables
tool/         scripts de génération d'icônes et de build
```