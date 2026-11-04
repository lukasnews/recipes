# BaCo in den Play Store bringen

Schritt für Schritt, alles am Handy oder im Browser machbar. Reihenfolge einhalten.

## 1. App in der Play Console anlegen

Play Console → **App erstellen**
- App-Name: **BaCo – Bake & Cook**
- Standardsprache: Deutsch (Österreich) – de-AT
- App oder Spiel: App · Kostenlos
- Erklärungen bestätigen → **App erstellen**

## 2. Erstes App-Bundle hochladen (einmalig von Hand)

1. GitHub → Actions → **CI** → **Run workflow** → Branch `ccr-9742725b-3t2jqk`, Häkchen „Auch App-Bundle (AAB)“ → Run.
2. Nach ca. 10 Minuten: Releases → neuestes „BaCo Android build N“ → **BaCo.aab** herunterladen.
3. Play Console → **Testen → Interner Test** → **Neuen Release erstellen**.
4. Bei „App-Signatur“: **Google Play App Signing** verwenden (Standard) → Weiter.
5. BaCo.aab hochladen → Release-Name z. B. „1.0.0“ → Speichern → Überprüfen → **Einführung starten**.
6. Reiter **Tester** → E-Mail-Liste anlegen (Gmail-Adressen der Tester) → Speichern → **Link kopieren** und an die Tester schicken. Die Tester öffnen den Link, tippen „Tester werden“ und installieren über den Play Store.

> Wichtig: Die Test-APK (aus GitHub) und die Play-Version kann man nicht gleichzeitig installieren, weil sie verschieden signiert sind. Vorher die Test-APK deinstallieren (Daten liegen in der Cloud und kommen nach dem Anmelden wieder).

## 3. Google-Login für die Play-Version freischalten

Google signiert die Play-Version mit einem eigenen Schlüssel. Dessen Fingerabdrücke braucht Firebase.

1. Play Console → **Testen und veröffentlichen → App-Integrität → App-Signatur** → beim **App-Signaturschlüssel** SHA-1 und SHA-256 kopieren.
2. Firebase-Konsole → Projekteinstellungen (Zahnrad) → Android-App `com.javuno.recipes` → **Fingerabdruck hinzufügen** → beide einfügen → Speichern.

## 4. App Check für die Play-Version

1. Firebase → **App Check** → Apps → Android-App → **Play Integrity** → SHA-256 des App-Signaturschlüssels (aus Schritt 3) eintragen → Speichern.
2. Play Console → **App-Integrität** → **Integrity API** → **Cloud-Projekt verknüpfen** → Projekt `recipes-f1584`.

## 5. Automatischer Upload (release.yml)

Damit künftige Versionen per Versionsmarke hochgeladen werden:

1. Google Cloud Console (Projekt `recipes-f1584`) → **IAM und Verwaltung → Dienstkonten** → **Dienstkonto erstellen** → Name `play-upload` → Fertig (keine Rollen nötig).
2. Dienstkonto öffnen → **Schlüssel → Schlüssel hinzufügen → JSON** → Datei wird heruntergeladen.
3. Play Console (Startseite, nicht in der App) → **Nutzer und Berechtigungen** → **Neue Nutzer einladen** → E-Mail des Dienstkontos (`play-upload@recipes-f1584.iam.gserviceaccount.com`) → App-Berechtigung für BaCo: **Releases verwalten** (Test-Tracks) → Einladen.
4. GitHub → Settings → Secrets → Actions → **PLAY_SERVICE_ACCOUNT_JSON** = kompletter Inhalt der JSON-Datei. Datei danach am Handy löschen.
5. Ab dann: neue Version = Tag `v1.0.1` usw. (oder Actions → „Release to Google Play“ → Run workflow). Landet automatisch im internen Test.

## 6. Store-Eintrag und Pflichtangaben

Play Console → **Dashboard** führt durch alles. Die Antworten:

**Datenschutzerklärung (URL):** `https://lukasnews.github.io/recipes/datenschutz.html`

**App-Zugriff:** „Alle oder einige Funktionen sind eingeschränkt“ → Anmeldedaten eines Test-Kontos (E-Mail/Passwort) für die Google-Prüfer eintragen. Erst für geschlossenen Test/Produktion nötig.

**Werbung:** Nein.

**Inhaltseinstufung:** Kategorie „Dienstprogramm/Produktivität“, alle Fragen Nein → Einstufung „Jeder“/PEGI 3.

**Zielgruppe:** 18 Jahre und älter (vermeidet die Kinder-Richtlinien).

**Kontolöschung:**
- Kann man in der App ein Konto erstellen? Ja.
- Link zum Löschen: `https://lukasnews.github.io/recipes/konto-loeschen.html`

**Datensicherheit:**
| Frage | Antwort |
| --- | --- |
| Werden Daten erhoben oder geteilt? | Ja, erhoben. Geteilt: Nein (Firebase ist Auftragsverarbeiter, zählt nicht als Teilen) |
| Verschlüsselt bei der Übertragung? | Ja |
| Können Nutzer Löschung anfordern? | Ja |
| Persönliche Daten → Name | erhoben, erforderlich, App-Funktionen + Kontoverwaltung |
| Persönliche Daten → E-Mail-Adresse | erhoben, erforderlich, Kontoverwaltung |
| Persönliche Daten → Nutzer-IDs | erhoben, erforderlich, Kontoverwaltung |
| Gesundheit und Fitness → Gesundheitsinformationen (Allergien) | erhoben, optional, App-Funktionen |
| Fotos und Videos → Fotos | erhoben, optional, App-Funktionen |
| App-Aktivitäten → Andere nutzergenerierte Inhalte (Rezepte, Listen) | erhoben, erforderlich, App-Funktionen |
| App-Info und Leistung → Absturzprotokolle, Diagnosedaten | erhoben, erforderlich, Analyse (Fehlerbehebung) |
| Geräte- oder andere IDs | erhoben, erforderlich, Analyse + Betrugsprävention (Crashlytics, App Check) |

**Store-Eintrag – Kurzbeschreibung (max. 80 Zeichen):**
> Rezepte, Einkaufsliste und Vorrat für den ganzen Haushalt – auch offline.

**Store-Eintrag – Beschreibung:**
> BaCo – Bake & Cook ist das Kochbuch für deinen Haushalt.
>
> • Rezepte sammeln: abtippen, abfotografieren (auch Handschrift und Screenshots) oder per Link aus dem Browser teilen. Mehrere Rezepte auf einem Foto werden erkannt.
> • Gemeinsam einkaufen: eine Einkaufsliste für alle, live abgeglichen, nach Abteilungen sortiert. Fehlende Zutaten eines Rezepts oder der ganzen Woche mit einem Tipp auf die Liste.
> • Vorrat im Blick: was im Kühlschrank, in der Speis und im Tiefkühler ist – mit Ablaufdatum, Mindestbestand und Barcode-Scan. Gekochtes zieht automatisch ab.
> • Was kann ich kochen? BaCo zeigt, welche Rezepte du mit dem Vorrat kochen kannst, und bevorzugt, was bald abläuft.
> • Kochmodus: Schritt für Schritt, Bildschirm bleibt an, Timer aus dem Rezepttext – mit Erinnerung auch bei geschlossener App.
> • Wochenplan mit Rezepten und Gerichten aus dem Tiefkühler.
> • Allergien pro Person mit Warnung im Rezept.
> • Österreichisch: Topfen, Schlagobers, Paradeiser, Erdäpfel – und Mengen in Dekagramm, wenn du willst.
> • Offline nutzbar, Abgleich sobald wieder Netz da ist. Keine Werbung.

**Grafiken:** App-Symbol 512×512 PNG, Vorstellungsgrafik 1024×500, mindestens 2 Handy-Screenshots (einfach Screenshots aus der App).

## 7. Danach: geschlossener Test → Produktion

Für neue private Entwicklerkonten verlangt Google vor der Veröffentlichung einen **geschlossenen Test mit mindestens 12 Testern über 14 Tage**. Dann Play Console → „Produktionszugriff beantragen“.
