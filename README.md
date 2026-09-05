# FitPulse

A dark, glassmorphic strength-training tracker for Android, built with Flutter.
Log every set of a 3-day split, see last session's numbers as ghost values while
you type, rest on a timer, and watch the strength curves build.

Everything is stored locally in SQLite. No account, no network calls.

---

## Getting it running

Flutter is not installed on this machine yet, so start there.

**1. Install Flutter + the Android toolchain**

- Flutter SDK: <https://docs.flutter.dev/get-started/install/windows>
- Android Studio (for the Android SDK, platform tools and an emulator)
- Then confirm the toolchain is healthy:

```bash
flutter doctor
```

**2. Run the one-time setup script from this folder**

```bash
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

It generates the `android/` platform folder, runs `flutter pub get`, and runs the
Drift code generator that produces `lib/data/db/app_database.g.dart`. It never
touches `lib/`, `assets/` or `pubspec.yaml`, so it is safe to re-run.

**3. Launch it**

```bash
flutter run
```

If you prefer to do it by hand instead of the script:

```bash
flutter create --org com.alimansoor --project-name fitpulse --platforms android .
```

```bash
flutter pub get
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

> `app_database.g.dart` is generated, not committed. Until `build_runner` has run
> once, the analyzer will flag `part 'app_database.g.dart'` as missing - that is
> expected.

---

## The training split

Seeded into the database on first launch, and editable at the data layer.

| Day | Focus | Exercises |
|-----|-------|-----------|
| 1 | Chest & Triceps / الصدر والترايسبس | Incline Chest Press, Flat Chest Press, Cable Chest Flyes, Triceps Cable Pushdown, Overhead Triceps Extension |
| 2 | Back & Biceps / الظهر والبايسبس | Lat Pulldown, Seated Cable Row, One-Arm Dumbbell Row, Biceps Barbell/Cable Curl, Hammer Curls |
| 3 | Legs & Shoulders / الأرجل والأكتاف | Leg Extension, Leg Press, Leg Curl, Dumbbell Shoulder Press, Lateral Raise, Rear Delt Fly |
| 4 | Rest Day / يوم راحة | - |

Days are picked manually - the app never advances the cycle for you. Each
exercise carries its prescribed set count ("3 sets", "2-3 sets", "4 sets") and its
own rest duration; sets can be added with **Add set** or removed by swiping left.

---

## Progressive overload

- **Ghost values.** The hint text inside every weight and reps field is what you
  lifted for that same set slot last time. Nothing is pre-filled, so the target is
  visible without ever being mistaken for a logged value.
- **Suggested target.** A pill above the sets proposes the next jump: same reps at
  +2.5 kg once you hit 10 reps, otherwise one more rep at the same load. The step
  is configurable (1.25 / 2.5 / 5 kg).
- **Estimated 1RM.** Epley (`w x (1 + reps/30)`) drives the strength progression
  chart, taking the best completed set of each session.

"Last time" is resolved as the most recent *other* session containing that
exercise, so a mid-session edit never pollutes its own reference values.

---

## Screens

| Screen | What it does |
|--------|--------------|
| **Onboarding** | Captures a display name locally, no auth |
| **Today** | Greeting, weekly stats, focus card, the 4-day split, recent sessions |
| **Workout** | Ticked meter, live duration and volume, per-exercise set logging, rest timer |
| **Progress** | Totals, weekly consistency strip, volume bar chart, 1RM line chart, session history |
| **Settings** | Name, weekly goal, default rest, auto-rest, overload step, Arabic names, data reset |

---

## Architecture

```
lib/
  core/            theme, reusable glass widgets, painters, formatters
  data/
    db/            Drift tables, seed data, AppDatabase (queries + analytics SQL)
    repositories/  WorkoutRepository - the only API the UI talks to
  domain/          plain read models (SessionSummary, ProgressPoint, GhostSet...)
  features/        onboarding, home, workout, history, settings, shell
  state/           Riverpod providers, settings controller, rest timer
```

- **State:** Riverpod 2. Drift streams feed `StreamProvider`s, so a set written to
  SQLite repaints the meter, the totals and the charts with no manual refresh.
- **Persistence:** Drift over SQLite (`fitpulse.sqlite` in the app documents
  directory). Local PostgreSQL is not viable on Android - it needs a server
  process the OS will not host - so SQLite is the equivalent local store.
- **Schema:** `exercises` (routine), `workout_sessions` (one per workout),
  `set_logs` (weight x reps x completed, cascade-deleted with the session).

---

## Design system

| Token | Value |
|-------|-------|
| Background | `#0B111E` -> `#0D1527` vertical gradient |
| Glass fill | white 8%, border white 8% (bright 20% when highlighted) |
| Accents | `#0088FF` -> `#00E5FF` gradient, `#22E58A` for completion |
| Type | Sora (variable) for UI, Cairo for Arabic names |

The neon glow is painted with radial gradients rather than blur filters, and the
frosted panels use a single `BackdropFilter` each, which keeps the whole thing
smooth on mid-range Android hardware. Micro-interactions: press-scale on every
tappable surface, spring on the set checkmark, animated ring/meter sweeps,
staggered screen entrances, and haptics on set completion and timer end.

---

## Not in v1

GPS/running tracking, step counting, workout reminders, data export, and an
in-app routine editor were scoped out. The database schema already supports a
routine editor (order, sets and rest are all columns), so that one is additive.

---

## Tests

```bash
flutter test
```

Covers the formatting and progressive-overload maths in `lib/core/utils/formatters.dart`.
