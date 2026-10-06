# Voice Task App (Mia)

Flutter app with a **parent shell** (`lib/app/`), reusable **core** (`lib/core/`), **Mia** tasks (`lib/mia/`), and **Calendar** (`lib/cal/`).

Companion Chrome extension (separate repo):
[mia-calendar-extension](https://github.com/MaadhiniNarayanaKumar/mia-calendar-extension)

---

## 1. What’s on

| Area | Status |
|------|--------|
| Parent home (2×2 grid: Voice, Add task, Categories, Calendar) | **On** |
| Profile sidebar → Settings / Open Mia | **On** |
| Theme packs (Mia / Focus / Cal) + Settings appearance | **On** |
| Mia tasks, categories, voice (needs `.env` keys) | **On** |
| Calendar agenda + add event (Firestore) | **On** |
| Chrome extension → Firestore events | **On** (separate repo) |
| Firebase Auth login UI | **Off** (`skipSignIn = true` → `local-guest`) |
| Google Calendar OAuth sync | **Removed / deferred** |
| FCM push | **Off** |

**Layout**

```text
lib/
  main.dart
  app/          # home, settings, auth
  core/         # theme, settings, voice, config
  mia/          # tasks module
  cal/          # calendar module (Firestore events)
assets/themes/
.env                # local secrets (gitignored)
.env.example
```

**Dependency rule:** `mia` → `core`, `cal` → `core`. Parent may use all.

---

## 2. Secrets (`.env`)

```bash
cp .env.example .env
```

| Variable | Purpose |
|----------|---------|
| `ASSEMBLYAI_API_KEY` | Voice speech-to-text |
| `GEMINI_API_KEY` | Title/category enrichment + intents |
| `GCP_API_KEY` | Optional fallback |
| `FUNCTIONS_URL` | Optional Cloud Functions override |

Full-restart after editing `.env` (not hot reload).

---

## 3. Calendar (no Google required)

Events: `users/{uid}/events` with a **source** field (`manual` / `extension`).

| Feature | Status |
|---------|--------|
| Day-wise agenda (Today / Tomorrow / …) | **On** |
| Week strip, Agenda / Day / Week / Month | **On** |
| Add event (type + **Parse invite** paste) | **On** |
| Voice add event (mic) | **On** (needs AssemblyAI in `.env`) |
| Chrome extension paste/parse/scrape | **On** (companion repo) |

**In app:** Home → Calendar → mic or **Add**. Swipe to delete; long-press to edit.

---

## 4. Chrome extension

Repo: [mia-calendar-extension](https://github.com/MaadhiniNarayanaKumar/mia-calendar-extension)

Clone next to this app (or anywhere), load unpacked in Chrome, and point `config.js` at the same Firebase project / `local-guest` uid.

---

## 5. Mia (short)

| API | Status |
|-----|--------|
| `Mia.open` / `Mia.quickAddTask` / `Mia.todaySummary` | **On** |
| Voice intents, categories, dashboard | **On** |

---

## 6. Run

```bash
flutter pub get
flutter run
```

Requires Firebase (`firebase_options.dart`). Firestore rules currently allow open access for local guest testing — tighten before shipping.

---

## 7. Security

- Keep real keys in **`.env`** (gitignored). Extension secrets live in that repo’s `config.js`.
- Rotate any keys that were ever committed to source.
