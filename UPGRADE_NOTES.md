# Wirdi v1.1.0 — Production Upgrade Notes

This documents the audit/upgrade pass performed on top of the working
v1.0.0 codebase (Quran, Azkar, Tasbeeh, Prayer Times, Home, GitHub Actions
build — all already functional and building on a real device).

## What changed and why

### Architecture / code quality
- **Removed duplicated code**: `quran_screen.dart` had its own copy of the
  Quran-fetching/parsing logic (`QuranApi`, `SurahData`, `AyahData`)
  duplicating `QuranRepository`/`quran_models.dart`. Now there is exactly
  one Quran data path.
- **New `core/services/` layer**: `local_cache_service.dart`,
  `azkar_repository.dart`, `prayer_service.dart`, `settings_service.dart`,
  `user_progress_service.dart`. Screens no longer talk to `http`/
  `SharedPreferences` directly for anything that's shared state — they go
  through a repository/service, so Home Dashboard, Quran, Azkar, and
  Prayer Times all read the *same* persisted state instead of drifting.
- **New `core/models/`**: `azkar_models.dart`, `prayer_models.dart`.

### Offline-first
- `QuranRepository` and `AzkarRepository` now cache the last successful
  fetch (`SharedPreferences`) and serve it instantly on next launch while
  refreshing in the background. No cache + no network still surfaces a
  real, user-facing error with a retry button (never fake data).
- `PrayerService` caches the last successful AlAdhan response and falls
  back to it if location/network fails, with the UI clearly labeling the
  times as "آخر مواقيت محفوظة (بدون اتصال)" — never presented as live.

### Azkar — was hardcoded sample data, now real
- Replaced the 4-category hardcoded `Map` with `AzkarRepository`, pulling
  the full ~132-category Hisn Al Muslim dataset your app was already
  configured to point at (`AppSources.azkarJsonUrl`), offline-cached.
- Added: search (category + text), favorites (persisted), per-item
  counters that persist and **reset daily** (based on the actual date, not
  a fake timer), completion detection + haptic + snackbar, share-via-copy
  (no new dependency — uses Flutter's built-in `Clipboard`).

### Tasbeeh
- 6 selectable phrases instead of one fixed counter, each with its own
  persisted daily count + all-time total, progress ring toward a
  per-phrase target, daily reset that's actually date-based.

### Prayer Times
- Logic extracted into `PrayerService` so Home Dashboard's "next prayer"
  and the Prayer Times screen can never disagree.
- Real, distinct error states (`PrayerAvailability` enum): location
  service off, permission denied, denied forever, no network + no cache —
  each with its own message, instead of one generic string.

### Home Dashboard — was static placeholder text, now real
- Next prayer + live countdown: real, from `PrayerService`.
- Continue reading: real, from the last-saved reading position.
- Favorites count: real, summed across Quran ayahs + Azkar items.
- Daily wird progress: real. Added a "mark this surah as read today"
  action in the Quran reader that increments actual persisted progress
  against a target you set in Settings, plus a real streak counter.
- Quote of the day: a curated, deterministic-by-date rotation (not an
  external API call, not lorem-ipsum — real short ayat/hadith text).

### Settings (new module)
- Theme: light / dark / system, persisted, applies live (no restart).
- Font size slider, persisted, applies app-wide via `TextScaler`.
- Daily wird target stepper.
- About, Sources & Licenses (reuses your existing `AppSources` content,
  plus Flutter's built-in open-source license page), Privacy Policy
  (written to match exactly what this codebase does — see below), and a
  "delete all local data" action with a confirmation dialog.

### Play Store readiness
- In-app Privacy Policy page now exists and accurately describes: no
  accounts, location used only for prayer-time calculation and not
  stored/shared, all other data local-only, which three external data
  sources the app calls, no ads, no analytics.
- **You still need to**: host this policy text (or equivalent) at a public
  URL for the Play Console listing — I can't host a URL for you. Also
  still needed before submission: real app icon/screenshots, a completed
  Play Console Data Safety form (the privacy text above tells you exactly
  what to declare), and a human legal read-through if you're in a
  jurisdiction with extra requirements.

## Explicitly NOT done in this pass (and why)

- **Full offline audio recitation library**: this is gigabytes of
  licensed audio files. Bundling "the entire Quran, offline, all
  reciters" isn't something that fits in an app download either
  technically or in terms of what I can source/verify here. The
  architecture (repository pattern, offline cache) is ready for a
  streaming-with-download-for-offline audio feature as a follow-up.
- **Riverpod / clean-architecture DI / sqflite or Isar for local
  storage**: you asked me not to risk breaking the Android build with new
  dependencies, and I can't compile-test locally in this sandbox. Current
  code stays on `SharedPreferences` + a repository pattern, which is a
  real, working offline-first design — just not a full DB-backed one.
- **Formal accessibility audit / performance profiling**: needs a running
  device/DevTools session, which I don't have here.
- **Qibla compass**: still out of scope per your own v1.0 brief (deferred
  to v1.1 in your original spec, and needs real-device compass testing).

## Before you rely on this build

I could not run `flutter analyze` / `flutter build` locally (no Flutter
SDK reachable from this sandbox — see the GitHub Actions workflow notes
in the main README). I reviewed every changed file manually (imports,
brace/paren balance, consistent method signatures across the new service
layer), but the real verification is your CI run. If it fails, paste me
the exact log and I'll fix it — I'd rather see the real compiler error
than guess.

---

# v1.2.0 — Quran/Azkar/Tasbeeh depth pass

Responding to the follow-up feature review. Scoped realistically — see
"Deferred" below for what's intentionally not in this pass and why.

## Added

**Quran module**
- Real per-ayah and per-surah audio (Mishary Alafasy, verified CDN:
  `cdn.islamic.network` — pattern confirmed against the official
  AlQuran.Cloud CDN docs). Per-ayah global numbering is computed live
  from your already-loaded Quran data (no separate mapping file to get
  out of sync).
- Per-ayah repeat toggle.
- Juz' (30-part) index — tap any Juz to jump straight to its starting
  ayah. Standard canonical boundary table.
- Full-Quran ayah text search (separate tab from surah-name search).
- Quran favorites tab (was only reachable indirectly before).
- "Continue reading" on the Home Dashboard now deep-links into the exact
  saved surah and **scrolls to the exact ayah**, instead of just opening
  the surah list.
- In-reader font zoom (+/-) and copy-ayah-to-clipboard.

**Azkar**
- Per-category completion progress bar (shown in both the category list
  and inside each category).
- "Hide completed" toggle inside a category.

**Tasbeeh**
- Custom counters: add any phrase + target via a dialog, persisted,
  long-press to delete. Sits alongside the 6 built-in phrases.

## New dependency

Added exactly one: `audioplayers: ^6.1.0`. This is a mature, widely-used
Flutter audio package — a calculated exception to the "no new
dependencies" rule from the previous pass, because audio playback was
your #1-ranked missing feature and there's no way to add it without an
audio-playing package. I could not compile-test it here (no Flutter SDK
in this sandbox); if your CI build fails on this dependency specifically,
send me the log and I'll adjust.

## Deferred (with reasons)

- **Tafsir**: I looked for a real, reliable tafsir data source and
  couldn't verify one reachable from this sandbox in the time available.
  Rather than guess at a URL or fabricate text, I'm leaving this out
  until a real source is confirmed.
- **Share ayah as image**: needs an image-rendering package
  (e.g. `screenshot` + share sheet) — next pass.
- **Weekly/monthly Tasbeeh statistics, achievements/gamification,
  statistics screen**: each is a real feature needing its own data model
  (weekly/monthly aggregation isn't just "read more prefs keys" — it
  needs a proper history log, which the current daily-only counters
  don't keep yet). Next pass.
- **Khatma duration goals (30/20/15/10 day plans)**: needs a slightly
  different data model than the current "daily wird target" (a khatma
  plan recalculates the daily target from remaining days, and needs to
  survive across app restarts correctly) — planned for the next pass
  alongside the statistics screen, since they share underlying data.
- **Home screen widget, notifications, night reading mode as a distinct
  theme, Lottie animations, glass/blur design overhaul**: each is a
  separate platform integration or design system change or on their own,
  not incremental additions to today's screens.

---

# v1.3.0 — Audit pass: gaps closed, code quality, real Khatma progress

This pass re-checked the app against the full production checklist
(items 1-12) against what v1.1.0/v1.2.0 actually shipped, rather than
starting over. Found and fixed real gaps; no new project uploaded, so
this builds on the existing codebase directly.

## Gaps found and fixed

**Code quality (item 10)**
- 4 remaining uses of the deprecated `Color.withOpacity()` in
  `splash_screen.dart` and `onboarding_screen.dart` (missed in earlier
  passes — everything else had already moved to `withValues(alpha:)`).
  Fixed for consistency and to avoid the deprecation warning.
- Removed a genuinely dead asset: `assets/data/placeholder.json` (a
  literal 3-byte placeholder file left over from the original scaffold)
  and its `pubspec.yaml` reference. This is exactly the kind of leftover
  the "no placeholder" rule is about — it wasn't used by any code.
- 3 silently-swallowed `catch (_)` blocks in the offline-fallback paths
  (`QuranRepository`, `AzkarRepository`, `PrayerService`) now log the
  real error via a new `AppLogger` (wraps `dart:developer.log` — zero new
  dependencies) before falling back to cache. Behavior is unchanged; you
  can now actually see *why* a fallback happened in `adb logcat` /
  DevTools instead of it being invisible.
- Removed the unused `intl` dependency by actually using it (see Data
  Management below) instead of leaving it declared-but-dead.

**Item 1 (Quran) — "Reading progress" was declared but not real**
- Added genuine khatma/reading-progress tracking: marking a surah as
  read (via the existing "add to daily wird" button) now also records it
  in a persisted completed-surahs set. The Quran tab shows a real
  progress bar + percentage ("تقدّم الختمة"), and the Home Dashboard
  shows the same percentage under the streak line. This is surah-level
  (not mushaf-page-level, since the Quran text source doesn't carry
  official page numbers) — stated explicitly, not implied to be more
  precise than it is.
- Added a "reset khatma progress" action in Settings for starting a new
  reading cycle without touching favorites or the daily wird streak.

**Item 6 (Settings) — Data Management was thin**
- Added real cache-freshness display ("آخر تحديث للقرآن الكريم" /
  "للأذكار") using the `cachedAt()` timestamps the repositories already
  tracked internally but never surfaced to the user, plus a manual
  "تحديث البيانات الآن" action.

**Item 8/9 (UI/UX, Performance)**
- `SurahReaderScreen`'s ayah list was still built eagerly
  (`ListView(children: [...])`) — for long surahs (e.g. Al-Baqarah, 286
  ayat) this builds all 286 cards upfront. Converted to
  `ListView.builder` for lazy on-screen building.
- Added `Semantics` labels to the custom interactive widgets that had
  none: the Tasbeeh counter circle, the Home Dashboard progress rings,
  and the per-ayah audio/favorite icon buttons in the reader — these are
  the widgets a screen reader couldn't previously describe meaningfully
  (regular `IconButton`/`Card` widgets elsewhere already get reasonable
  default semantics from Flutter, and existing `tooltip` values also
  help).

## What I checked and found already done (from earlier passes)

Offline-first repository pattern, Quran/Azkar/Prayer caching, full
Hisn Al Muslim dataset, Quran search (name/number/verse text), Juz
index, favorites (Quran + Azkar), Azkar counters/completion/progress
bars/share, Tasbeeh multi-phrase + custom counters + daily/total stats,
GPS prayer times with offline fallback and real error states, live
countdown, Home Dashboard wired to real data (no hardcoded values
remain), theme (light/dark/system) + font size, About/Sources/Privacy
Policy/Data Management, GitHub Actions build. I did not re-do any of
these — re-verified they're real, not re-implemented from scratch.

## Still deferred (unchanged from v1.2.0, still true)

Tafsir (no verified source yet), share-ayah-as-image, weekly/monthly
Tasbeeh statistics + a dedicated achievements/gamification screen,
Khatma **duration-based plans** (30/20/15/10-day pace calculator — note
this is different from the progress tracking added in this pass, which
just tracks *what's* been completed, not a target pace), home-screen
widget, push notifications/daily reminders, full English translation
(the `Locale`/`flutter_localizations` infrastructure is in place from
v1.1.0, but translating every hardcoded Arabic string in every screen is
its own large, mechanical task better done as one clean pass), and the
Lottie/glass-blur visual redesign. Each remains out of scope here for
the same reasons as before: needs a new dependency I haven't vetted, a
data model that doesn't exist yet, or platform integration I can't test
in this sandbox.

## Verification

Same limitation as prior passes: no Flutter SDK reachable from this
sandbox, so I checked every changed file by hand — brace/paren balance
across the whole `lib/` tree, and that every relative import in touched
files resolves to a real file. The one thing I added real risk-awareness
for: `DateFormat(..., 'ar')` in Settings needs Arabic locale data loaded,
so `main()` now explicitly calls `initializeDateFormatting('ar', null)`
at startup rather than assuming `flutter_localizations` already did it.
Push and let CI confirm; send me the log if anything fails.

---

# v1.3.1 — Build fix

Your CI caught a real bug: `lib/features/settings/settings_screen.dart:129:54: Error: Member not found: 'rtl'`.

**Root cause**: `package:intl` exports its own `TextDirection` enum
(`LTR`/`RTL`/`UNKNOWN`) which collides with Flutter's `dart:ui.TextDirection`
(`rtl`/`ltr`) when both packages are imported unqualified in the same file.
I added `import 'package:intl/intl.dart';` to `settings_screen.dart` for the
new cache-freshness date formatting, and it shadowed Flutter's
`TextDirection.rtl` used elsewhere in that same file — a known gotcha
when mixing `intl` and Flutter in one file.

**Fix**: `import 'package:intl/intl.dart' hide TextDirection;` — keeps
`DateFormat` available, excludes the colliding enum, so Flutter's
`TextDirection.rtl` resolves correctly again.

Checked the rest of the project for the same pattern: `main.dart` also
uses `intl` (for `initializeDateFormatting`) but only imports
`package:intl/date_symbol_data_local.dart`, which doesn't re-export
`TextDirection` — so it wasn't affected. No other file imports `intl`.

---

# v1.4.0 — Real-usage bug fixes + feature requests

Based on actual device testing feedback. Prioritized real bugs first,
then feature requests, in the order reported.

## Bugs fixed

- **Audio playback failing on every attempt** ("تعذر تشغيل الصوت"):
  root cause was `audioplayers`' `.stop()` throwing when nothing was
  loaded yet — which is exactly the state on the very first tap. That
  exception was being caught and shown as a generic failure message
  every time. Fixed by isolating `.stop()` in its own try/catch and
  surfacing the *real* exception text if playback genuinely fails, so
  any future issue is diagnosable instead of a dead end.
- **Search failing on undiacritized input**: Quran text is fully
  vocalized (tashkeel) but users type plain letters. Added
  `ArabicTextUtils.normalize()` (strips diacritics/tatweel, folds
  أ/إ/آ→ا, ى→ي, ة→ه, ؤ→و, ئ→ي) and wired it into Quran surah-name search,
  Quran ayah-text search, and Azkar search.
- **Dark mode: Quran screens had light patches other screens didn't**:
  confirmed via project-wide grep that `quran_screen.dart` alone had
  hardcoded `Color(0xFFF8FAF6)` / `Colors.white` — replaced with
  theme-aware colors (`Theme.of(context).cardColor`, etc.) so it follows
  the same dark/light theme as every other screen.

## Features added

- **Multiple reciters**: 6 verified real reciters (Alafasy, Husary,
  Minshawi, Abdul Basit, Sudais, Maher Al-Muaiqly) from the same CDN
  already in use. Picker in the Surah reader, persisted app-wide.
- **Prayer location name**: resolved via OpenStreetMap Nominatim reverse
  geocoding (free, no key, uses the existing `http` dependency — no new
  package). Shown above the next-prayer card.
- **Manual city entry for prayer times**: uses AlAdhan's own
  `timingsByAddress` endpoint (geocodes server-side, same trusted
  provider already in use). Accessible via the prayer screen's menu or
  from the location-error screen.
- **Prayer mode persists across GPS being turned off**: last-used mode
  (GPS or manual city) and the last successful result are both cached,
  so closing location services doesn't lose your prayer times — this
  extends the offline-fallback behavior from v1.1.0 to also remember
  *which* location source you were using.
- **Mark prayer as done**: a checkbox per prayer, persisted per day.
- **Prayer reminder**: toggle, minutes-before slider, banner/sound/both
  mode, in Settings. **Explicitly labeled in the UI itself** as
  foreground-only (works while the app/screen is open) — true
  background push notifications need a notifications package and
  platform-level permission work I'm not adding sight-unseen; noted as
  a planned follow-up rather than silently limited.
- **Gregorian + Hijri date** on the Home Dashboard: pure-Dart tabular
  Hijri conversion (standard arithmetic algorithm, no new dependency).
  Like any calculated Hijri date without an official lookup table, it
  can differ by a day from a locally-announced moon-sighting-based
  calendar — this is a general limitation of arithmetic Hijri
  conversion, not specific to this implementation.
- **Real Duas ("الأدعية") tab**: discovered the already-integrated Hisn
  Al Muslim dataset contains 60+ genuine dua-specific categories.
  Added a second tab on the Azkar screen that filters to just those,
  reusing the same trusted data source rather than introducing a new,
  unverified "dua database".

## Still not done (unchanged reasoning, or new and explained below)

- **Full mushaf-style paginated Quran view** (Uthmani script laid out as
  actual mushaf pages, switchable with the current list view): the
  current Quran text source doesn't carry official mushaf page-break
  data, so a real page-accurate rendering needs a different/additional
  data source. Doing a fake approximation would look broken; deferred
  until a verified page-layout dataset is found.
- **7-day accomplishment summary**: needs a proper daily history log
  (current tracking only keeps "today"'s counts, overwriting daily) —
  real implementation, not just more prefs keys, planned for next pass.
- **Gharib al-Quran (rare word glossary)**: no verified dataset found
  yet, same reasoning as Tafsir.
- **Tafsir**: still no verified source found.
- **True background Adhan/push notifications**: needs
  `flutter_local_notifications` (or similar) + Android exact-alarm
  permission handling — a real new dependency + platform integration I
  can't verify compiles without your CI. Candidate for a dedicated pass.
- **Full English translation**: infrastructure (`flutter_localizations`,
  `supportedLocales`) has been in place since v1.1.0; translating every
  hardcoded Arabic string across every screen is a large, mechanical
  task better done as one clean, complete pass rather than partially.
- **Muslim Pro-inspired ideas**: noted for consideration, no code
  changes from this alone — happy to look at specific features you like
  from it and scope them the same way as everything else here.

## Verification

Full project-wide check this pass, beyond the usual brace/paren balance:
verified every relative import in every touched file resolves to a real
file, cross-checked every new service method's signature against every
call site (`PrayerService`, `AppSettings`), and specifically re-checked
for the `intl`/`TextDirection` collision pattern that broke v1.3.0's CI
build — confirmed `home_dashboard_screen.dart` (which also now imports
`intl` for date formatting) already uses the `hide TextDirection` fix
consistently. Still can't compile locally; push and send me the log if
anything surfaces.

---

# v1.5.0 — Tafsir, Mushaf view, real Adhan sounds, 7-day history

Tackling the items explicitly deferred from v1.4.0. Researched real data
sources for each before writing any code (see verification notes below)
rather than guessing at URLs.

## Added

**Tafsir**
- Real Tafsir Al-Muyassar dataset (6,236 entries, one per ayah), from a
  GitHub-hosted JSON source — verified structure and reachability before
  integrating (`TafsirRepository`, same offline-first cache pattern as
  Quran/Azkar).
- Toggle button (📖 icon) per ayah in the Surah reader expands/collapses
  its tafsir inline. Lazy-loaded on first use, not on screen open, so it
  doesn't cost a 2.7MB download for users who never open it.

**Mushaf-style paginated view**
- Real 604-page Madani Mushaf ayah-to-page mapping dataset — verified
  structure (juz number + per-page ayah lists, correctly handling pages
  that span two surahs) before integrating (`MushafRepository`).
- New swipeable page-by-page reading screen (`MushafViewScreen`),
  accessible via a book icon in the Quran tab's AppBar. This is a
  genuine page-accurate layout (not a cosmetic approximation) using the
  same real ayah text already in the app, justified and paginated
  according to the real mushaf page boundaries.

**Real Adhan sounds**
- 6 real Adhan recordings, officially hosted by AlAdhan
  (`cdn.aladhan.com`) — the exact same trusted provider already used for
  prayer times, listed at their own `/download-adhans` page.
- Prayer reminder mode now has 3 real options: banner only, short beep
  (system sound), or full Adhan (actually plays the selected recording).
  Previously "sound" mode was just a generic system alert beep; this
  replaces that with real Adhan audio.
- Adhan recording is user-selectable in Settings.

**7-day activity summary**
- Real daily history log, not a derived/quick-hack estimate: wird pages,
  Azkar completions, and prayers-done were already being written to
  date-keyed storage (from earlier passes); Tasbeeh's daily total is now
  also date-keyed the same way (see bug fix below).
- Home Dashboard shows a genuine 7-day view: one dot per day, filled by
  activity level, checkmarked if that day's wird target was met, plus a
  "target met X of 7 days" line. Not a static/example graphic — every
  number comes from what was actually logged that day.

## Bug caught and fixed during this pass

Tasbeeh's day-key format (`'${year}-${month}-${day}'`, unpadded) didn't
match the zero-padded format used everywhere else in the app
(`UserProgressService.dateKeyFor`, e.g. `'2026-07-05'` vs `'2026-7-5'`).
Left as-is, the 7-day summary would have silently shown 0 Tasbeeh
activity forever, even with real usage, because the read and write keys
would never match. Fixed by routing Tasbeeh's daily total through a new
`UserProgressService.incrementTasbeehDailyTotal()` that uses the
consistent format — caught before shipping, not after.

## Deferred, with reasons

- **Background/closed-app Adhan notifications**: needs
  `flutter_local_notifications` *and* changes to the CI workflow's
  Android-manifest-patching step, since `android/` is regenerated fresh
  on every build rather than committed. Attempting this blind, stacked
  on top of everything else in this pass, risked breaking the whole
  build with no way for me to verify it compiles. This is a real,
  scoped-out feature for a dedicated pass, not abandoned.
- **Gharib al-Quran**: searched again specifically for this pass — found
  only word-tokenization datasets (word counts/positions), not actual
  meanings/glossary data. Won't fabricate word definitions.
- **Full English translation**: `flutter_localizations` +
  `supportedLocales` infrastructure has been ready since v1.1.0;
  translating every hardcoded Arabic string across ~30 files is a large,
  mechanical task that deserves its own complete, careful pass rather
  than a partial one squeezed alongside 4 other major features.
- **Qibla compass**: would need a second new native-integration
  dependency (`flutter_compass`) in the same pass as the Adhan/audio
  work — stacking two unverifiable native changes at once is how builds
  break. Next pass.

## Verification

Before writing any integration code: cloned/fetched each candidate
dataset directly (Tafsir repo, Mushaf-pages repo, AlAdhan's Adhan
download page) and confirmed real structure + HTTP 200, rather than
guessing at a URL — this is the same discipline that caught the earlier
tafsir dead-end without cluttering the app with a broken feature.
Post-implementation: full project-wide brace/paren balance check, every
relative import in every touched file resolves to a real file, and a
specific re-check for the `intl`/`TextDirection` collision pattern
(confirmed `home_dashboard_screen.dart`, `settings_screen.dart` both use
the `hide TextDirection` fix; `main.dart` only imports the sub-package
that doesn't have the conflict). Same standing limitation: no Flutter
SDK in this sandbox, so your CI run is still the real test — send me the
log either way.

---

# v1.5.1 — Build fix

Your CI caught a real bug I introduced in v1.5.0:

```
lib/features/mushaf/mushaf_view_screen.dart:113:17: Error: No named parameter with the name 'textDirection'.
```

**Root cause**: I put `textDirection: TextDirection.rtl` on a `TextSpan`
inside the new Mushaf page view. `TextSpan` doesn't have that parameter —
only `Text`/`Text.rich`/`RichText` do. The outer `Text.rich(...)` already
had `textDirection: TextDirection.rtl` correctly set; the inner one on
`TextSpan` was simply wrong. This one's on me, not an environment quirk
— removed it.

Also cleaned up two things `flutter analyze` flagged in the same run
(both were "info"/"warning", not build-blocking, but worth fixing since
"fix deprecated APIs" was on your original list):
- Removed an unused import in `settings_screen.dart`
  (`prayer_service.dart`, no longer referenced there).
- Replaced Geolocator's deprecated `desiredAccuracy:` parameter with the
  current `locationSettings: LocationSettings(accuracy: ...)` API in
  `PrayerService`.

Full `flutter analyze` output from your log for reference — remaining
items are non-blocking style suggestions (`prefer_const_constructors`,
`use_build_context_synchronously` guarded by existing `mounted` checks)
that don't affect the build; can clean those up in a future pass if you
want a fully warning-free `flutter analyze`.

---

# v1.6.0 — Real-device bug reports, second round

Your build succeeded (v1.5.1) — this pass addresses new issues found
through actual usage.

## Bugs fixed

- **Full-surah audio silent (per-ayah worked fine)**: the CDN's own docs
  warn that surah-level audio isn't guaranteed at every bitrate for
  every reciter, unlike ayah-level audio. Added a fallback that tries
  128→64→192→32 in order instead of assuming one value. I could not
  verify this empirically — the CDN blocks this sandbox's requests
  (403) — so this is the most defensible fix available, not a confirmed
  one. If it's still silent, the exact reciter+bitrate that works can be
  found from a browser on a real device and hardcoded as the first try.
- **Search result didn't jump to the actual ayah, only the surah start**:
  root cause found — `ListView.builder` only builds visible list items,
  so a search result far down a long surah (e.g. ayah 200) had no built
  widget yet, and `Scrollable.ensureVisible` was silently failing on a
  null context. Fixed with a real jump-then-refine approach: estimate
  the scroll position, jump there so the target enters the built range,
  then retry `ensureVisible` across a few frames.
- **Home Dashboard's "المفضلة" (Favorites) card opened the entire Azkar
  screen**, not a filtered favorites view, and didn't include Quran
  favorites at all. Built a real unified `FavoritesScreen` (Quran ayahs
  + Azkar, tabbed) and fixed the card to open it.

## Features added

- **Mark-as-prayed now time-gated**: the checkbox is disabled until a
  prayer's actual time has passed — you can no longer mark Isha done at
  9am.
- **Tasbeeh grand total**: a combined count across every phrase (built-in
  + custom), shown alongside the existing per-phrase total.
- **Adhan/beep preview**: replaced the plain dropdown with a real list
  where each of the 6 Adhan recordings has its own play/stop preview
  button, so you can hear before choosing. Added a "تجربة النغمة" preview
  button for the beep mode too.
- **7-day summary now starts on Saturday** (regional week-start
  convention) instead of a rolling "last 7 days ending today" window —
  it's now a real Saturday–Friday calendar week. Days later than today
  show as dimmed/not-yet-happened rather than blank. Day names switched
  from clipped 3-letter abbreviations to full names
  (السبت/الأحد/الاثنين/...) laid out with `Expanded` columns so they
  don't get cut off, and today is highlighted with a gold ring.

## Deferred, with reasons

- **Stop Adhan/reminder audio on volume button press**: needs
  intercepting hardware key events, which means custom `MainActivity.kt`
  code (overriding `dispatchKeyEvent`, a `MethodChannel` to notify
  Flutter) *and* a CI workflow update to inject that file after
  `flutter create` regenerates `android/` fresh every build (it isn't
  committed). This is real, buildable work, but it's its own isolated
  native-integration feature — bundling it into an already-large fix
  pass, unverifiable by me either way, is how a build breaks. Next
  focused pass.

## Verification

Full project-wide brace/paren balance check, every relative import in
every touched file resolves to a real file, a specific re-check for the
`TextSpan`/`textDirection` mistake class from v1.5.0 (none found this
time), the `intl`/`TextDirection` collision pattern (still correctly
guarded everywhere `intl` is imported), and confirmed the three
independent `AudioPlayer` instances (Quran reader, Prayer reminder,
Settings preview) don't share state. Same standing limitation: no
Flutter SDK in this sandbox, so your CI run is still the real test.
