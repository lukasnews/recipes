# BaCo – Bake & Cook

Flutter-App für einen Haushalt: Rezepte verwalten und importieren, gemeinsame Einkaufsliste und Vorrat. Offline-first, Sync über Firebase.

Details zu Architektur, Datenmodell und Roadmap: [CLAUDE.md](CLAUDE.md).

## Entwicklung

```bash
flutter pub get        # also generates lib/l10n/app_localizations*.dart
flutter analyze
flutter test
flutter run -d web-server --web-port 8080
```

## Firebase einrichten

1. Firebase-Projekt anlegen, Android-App `com.javuno.recipes` registrieren.
2. SHA-1 und SHA-256 des Upload-Keys eintragen (stehen in der Zusammenfassung jedes CI-Laufs).
3. Authentication: E-Mail/Passwort und Google aktivieren.
4. Firestore-Datenbank anlegen (europe-west3), Inhalt von `firestore.rules` unter „Regeln“ einfügen.
5. `google-services.json` nach `android/app/` legen und committen.

Regel-Tests: `cd test_rules && npm ci && npm test` (startet den Firestore-Emulator, braucht Java).

### Fotos und KI-Import
6. Storage aktivieren (Build → Storage), Inhalt von `storage.rules` unter „Regeln“ einfügen. Beim Veröffentlichen fragt Firebase, ob Storage Firestore lesen darf: bestätigen.
7. Build → AI Logic → „Get started“ → Gemini Developer API.
8. Optional: Remote Config `ai_model` setzen, um das Gemini-Modell zu wechseln.
