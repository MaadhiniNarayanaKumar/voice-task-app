# Voice Task App (Mia)

Flutter app with a **parent shell** (`lib/app/`), reusable **core** (`lib/core/`), **Mia** tasks (`lib/mia/`), and **Calendar** (`lib/cal/`).

Companion Chrome extensions (separate repos):

- [mia-calendar-extension](https://github.com/MaadhiniNarayanaKumar/mia-calendar-extension)
- [mia-task-extension](https://github.com/MaadhiniNarayanaKumar/mia-task-extension)

---

## 1. What’s on

| Area | Status |
|------|--------|
| Parent home (2×2 grid: Voice, Add task, Categories, Calendar) | **On** |
| Bottom bar: Home, Mia, Calendar | **On** |
| Profile sidebar → Settings / Open Mia | **On** |
| Theme packs (Mia / Focus / Cal) + Settings appearance | **On** |
| App icon (lavender M) | **On** |
| Mia tasks, categories, voice (needs `.env` keys) | **On** |
| Calendar agenda + add event (Firestore) | **On** |
| Chrome extensions → Firestore events and tasks | **On** (separate repos) |
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

Events: `users/{uid}/events` with a **source** field (`manual` / `extension`). Today’s date is the reference for the week, agenda, month, and new events.

| Feature | Status |
|---------|--------|
| Agenda / Day / Week / Month | **On** |
| One calendar at a time (week strip, or month grid) | **On** |
| Week view lists upcoming events, or one “No events” line | **On** |
| Finished events hidden; “Did you attend this event?” prompt | **On** |
| Work / Personal / Extension filters | **Removed** |
| Add event (type + **Parse invite** paste) | **On** |
| Voice add event (mic) | **On** (needs AssemblyAI in `.env`) |
| Refresh button and pull-to-refresh | **On** (same spinner) |
| Chrome extension paste/parse/scrape | **On** (companion repo) |

**In app:** Home → Calendar (tab or Quick actions) → mic or **Add**. Swipe to delete; long-press to edit. The tasks and calendar bottom bars match, with no selected highlight.

An event that has ended drops off the schedule. The app asks **Did you attend this event?** and stores `attended` (`true` / `false`) so it does not ask again.

---

## 4. Chrome extensions

| Repo | Writes |
|------|--------|
| [mia-calendar-extension](https://github.com/MaadhiniNarayanaKumar/mia-calendar-extension) | `users/{uid}/events` |
| [mia-task-extension](https://github.com/MaadhiniNarayanaKumar/mia-task-extension) | `users/{uid}/tasks` |

Clone next to this app (or anywhere), load unpacked in Chrome, and point each `config.js` at the same Firebase project / `local-guest` uid.

---

## 5. Mia (short)

| API | Status |
|-----|--------|
| `Mia.open` / `Mia.quickAddTask` / `Mia.todaySummary` | **On** |
| Voice intents, categories, dashboard | **On** |
| Completion progress card (“X of Y completed”) | **Removed** |
| Empty list | **All done** with a check icon |

---

## 6. Run

```bash
flutter pub get
flutter run
```

Requires Firebase (`firebase_options.dart`). Firestore rules currently allow open access for local guest testing — tighten before shipping.

---

## 7. Security

- Keep real keys in **`.env`** (gitignored). Extension secrets live in each repo’s `config.js`.
- Rotate any keys that were ever committed to source.
