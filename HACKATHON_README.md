> Historical plan/context: consult PROJECT.md for current verification.
> Event rules below are transcribed from the official iQOO Hackathon 2026 / City
> Battles rules page, shared 2026-09-07. Offline, accessibility, latency, and device
> claims elsewhere in this file are not current acceptance evidence. Follow AGENTS.md
> safety rules for all new work.

# Logic Legends — iQOO Hackathon 2026 · City Battles

## Event rules (official rules page)

### Judging — six dimensions, 100% total

| Dimension | Weight | Scored by | What it measures |
| --- | --- | --- | --- |
| End product quality | 30% | Jury panel | Does it work, is it useful, would someone keep using it |
| Novelty and impact | 20% | Jury panel | Originality and real-world impact |
| Creative phone use | 15% | **HackTracker** (device data) | Camera, voice, **on-device AI in the build** |
| Technical depth | 15% | Jury panel | Architecture, code quality, robustness, real use of the hardware |
| Office Kit usage | 10% | **HackTracker** (device data) | Phone-and-laptop bridge use |
| Demo and presentation | 10% | Jury panel | A compelling 3–5 minute pitch |

**HackTracker** is pre-installed on the loaner phone and captures *counts and
durations only* — no keystrokes, screenshots, or browsing content. It directly
measures whether on-device AI and Office Kit were actually used, not just claimed.

### Format
- **Phone-first**: every entry must run and pitch on the iQOO phone. A local or
  open-source model at the core "earns brownie points," with the phone in the loop
  via Office Kit; on-device inference targets the Snapdragon NPU. Free AI credits are
  provided for the weekend. Any stack qualifies (native Android, Flutter, React
  Native, PWA) as long as it runs phone-first with a local/open-source model at the
  core.
- Each **City Battle is 30 hours, all-inclusive**: Saturday ~08:00 check-in through
  Sunday ~17:00 awards. **Green Light** = both devices; **Red Light** = iQOO phone
  only, via Office Kit.
- **Two scored evaluation rounds** (Saturday evening, Sunday morning) feed a **Top 10
  pitch** — this is not a single end-of-weekend demo.
- **Grand Finale**: Bengaluru, **Oct 9–11, 2026**, 48 hours (Friday evening–Sunday
  evening). Top 6 teams per city advance (3 student teams + 3 working-professional
  teams); standout teams beyond the Top 6 can also earn Finale slots. Direct
  registration for the Grand Finale (skipping a city battle) is also possible.

### Devices
- One flagship iQOO **loaner** phone per person, handed over at Saturday check-in
  with **HackTracker pre-installed and Office Kit already paired**.
- Devices remain iQOO property — stay in the venue/hacking zone, return before exit.

### Tracks & buckets
- **Seven tracks** in city battles; the Grand Finale runs **six** (drops FinTech &
  Commerce, Smart Education, HealthTech; adds Mobility and Community App).
- Students and working professionals both compete, but **a team cannot mix buckets**.
- Tracks are broad domains, not fixed briefs; **Open Innovation** is the wildcard
  track everywhere.
- **Not yet known here:** which track this project is registered under. The earlier
  internal pitch used "Smart Living," which is **not** one of the named tracks above
  — confirm the actual registered track with the team before the pitch.

### Build rules — original work only
- **Code must be written during the event window** — no shipping a pre-built
  product. Open-source libraries/frameworks are fine with attribution; carrying in a
  finished app is not. **Organisers may verify a project was built inside the event
  window.**
- Submit the repo and demo assets on the **Reskilll platform** before the hard
  cutoff — repos are **locked before the Top 10 pitches**. Late submission risks
  scoring penalties or disqualification.
- Cheating, plagiarism, or unfair practice is immediate disqualification.

### Prizes & advancement
- **₹40,00,000** total pool across city battles, the Grand Finale, and special track
  awards.
- Top 6 teams per city advance to the Grand Finale (3 per bucket); standouts beyond
  Top 6 can also earn Finale slots.

### IP & data
- Teams **retain IP** on their submission. Participating grants iQOO/Reskilll a
  non-exclusive, royalty-free right to review, evaluate, and showcase the work for
  hackathon-related communications. Submissions are treated as confidential; any use
  beyond showcase needs a separate written agreement.

---

## Project alignment check (as of 2026-09-07)

| Rule / theme | Current project state | Risk |
| --- | --- | --- |
| On-device AI (15% Creative phone use, via HackTracker device data — not self-reported) | **Wired 2026-09-07**: `on_device_llm_service.dart` now runs Qwen3 0.6B locally via `flutter_gemma` (LiteRT-LM engine, `PreferredBackend.npu`, falls back to GPU/CPU automatically). `AiService.explain()` tries it first, falls back to cloud Gemini on failure/timeout. `flutter analyze` and a release build both pass. **Not yet run on a physical phone** — no device attached this session, so the download, actual NPU engagement, and latency are unverified. | Medium — the code path exists and should give HackTracker something real to count, but "implemented" isn't "device-verified." Confirm on the loaner iQOO phone before relying on this for judging. |
| Camera + voice use (the other 2/3 of Creative phone use) | Real and working: camera capture (tap/Volume-Up), ML Kit OCR, TTS throughout, `speech_to_text` in Voice Chat, physical volume-key handling. | Low — this part is genuinely strong. |
| Office Kit usage (10%, via HackTracker device data) | The phone-first APK build has no laptop runtime dependency, which is correct for Red Light — but HackTracker scores *actual* phone↔laptop bridge use during the event, so the team needs to actually exercise Office Kit (screen mirror / file transfer / remote control) during the build, not just be compatible with it. | Medium — a capability that's never exercised won't score. |
| Track registration | Old pitch used "Smart Living," which isn't in the current track list (FinTech & Commerce, Smart Education, HealthTech, Mobility\*, Community App\*, Open Innovation, + others; \*Finale-only additions). | Unknown — confirm the actual registered track; this is an accessibility assistant, so HealthTech, Community App, or Open Innovation are the closest fits pending confirmation. |
| Team size / bucket (solo or up to 3; student vs. professional, no mixing) | Not tracked in this repo. | Unknown — confirm with team. |
| **Original work / built during the event window** | This repo already carries substantial architecture, docs, and prior commits. Organisers may verify build timing. | **Worth confirming explicitly with the team** — not a code issue, but a compliance one: be ready to account for what was built inside this event's actual 30-hour window versus earlier prep, since it's an explicit disqualification condition. |
| Repo + demo submission on Reskilll platform, before the cutoff (locked pre-Top-10) | Not tracked here. | Action item — confirm submission is done ahead of the lock, separately from git commits to this repo. |
| Accessibility impact narrative (feeds End product quality 30%, Novelty 20%) | Real, working differentiator: two-stage Read & Explain (OCR fast path + LLM explanation + template fallback), physical-key capture/repeat, emergency-contact calling, offline SMS scam triage. See README.md/PROJECT.md for the exact current status per feature. | Low, provided demo claims stay limited to what PROJECT.md marks Implemented/Device verified — AGENTS.md forbids claiming offline/accurate/verified without current evidence. |
| Offline claims | Cache is real (7-day TTL, LRU), but the explanation step needs network today (cloud Gemini). "Offline" cannot be claimed to judges as a device-verified fact yet. | Medium |

**Status as of 2026-09-07:** the on-device wiring described above is done in code
(`flutter_gemma` + Qwen3 0.6B in `AiService.explain()`), analyzed clean, and builds a
release APK. What's left is entirely device verification, not more coding: confirm
the ~586MB first-run download completes on real venue wifi, confirm the NPU backend
actually engages (vs. silently falling back to GPU/CPU), and measure latency/RAM with
the camera also active. The fast OCR path and template fallback are untouched, so a
stalled or failed on-device call still can't leave the user in silence.

---

## Build for Event

```bash
# 1. Get dependencies
flutter pub get

# 2. Build release APK (for Office Kit install during Red Light)
flutter build apk --release --target-platform android-arm64

# 3. APK location: build/app/outputs/flutter-apk/app-release.apk
```

`constapi.dart` (Gemini API key) is gitignored — copy
`lib/screens/constapi.dart.example` and paste a real key before building.

---

## Office Kit Workflow (Red Light)

| Green Light (Laptop + phone) | Red Light (Phone only, via Office Kit) |
| --- | --- |
| `flutter build apk --release` | Test camera, GPS, AI, capture/repeat keys |
| Drag APK → Office Kit → install | Demo rehearsal, hands mostly off the laptop |
| Push test images/props to phone | Record demo video |
| Edit `assets/config/app_config.json` / `prompts.json` for feature flags and prompt wording (bundled assets — requires a rebuild, not a live edit) | Toggle settings, verify accessibility behavior |

---

## Key files (current, as of 2026-09-05 commit)

```
assets/
├── config/
│   ├── app_config.json       # feature flags, prompt/model config
│   └── prompts.json          # prompt templates per mode
├── images/                   # demo/test images
└── l10n/                     # en.json (supported); ta.json (kept, not demoed)

lib/
├── services/
│   ├── ai_service.dart               # cloud Gemini today; explain() is the on-device seam
│   ├── ocr_service.dart              # ML Kit on-device text recognition
│   ├── read_explain_logic.dart       # pure classify/fallback/prompt logic, has a dart-run self-check
│   ├── on_device_llm_service.dart    # stub — returns null (cloud fallback), P1 to wire flutter_gemma
│   ├── gemini_api_client.dart        # bounded authenticated Gemini REST client
│   ├── speech_config.dart            # single source for TTS rate/pitch/language
│   ├── hardware_keys.dart            # volume-rocker EventChannel + repeat buffer
│   ├── emergency_service.dart        # countdown, cancel, location, dialling
│   ├── sms_service.dart / sms_classifier.dart   # offline SMS triage (classifier is pure)
│   ├── gps_service.dart              # high-accuracy location + reverse geocode
│   ├── config_service.dart           # loads assets/config/*.json
│   ├── localization_service.dart     # en / ta strings (ta kept in build, not demoed)
│   ├── offline_cache_service.dart    # response cache (7-day TTL, LRU)
│   ├── browsing_service.dart         # DuckDuckGo scrape (Explore augmentation)
│   ├── voice_assistant_service.dart  # voice command parsing/dispatch
│   └── voice_chat_logic.dart         # Voice Chat turn-taking ("clear over") logic
├── widgets/debug_overlay.dart        # double-tap: FPS, GPS, cache, network, model
└── screens/
    ├── homepage.dart                 # camera, gestures, routing, emergency overlay
    ├── read_explain_screen.dart      # two-stage OCR + explanation coordinator
    ├── chatscreen.dart               # Explore-mode scene description
    └── settings_screen.dart          # toggles, emergency contact, wake word
```

There is no `assets/models/` directory and no bundled `.tflite` file in this repo —
do not claim an on-device model is bundled until one actually is.

---

## Pre-event checklist

- [ ] Confirm team roster and bucket (student / professional) against the rules above.
- [ ] Decide whether to attempt the on-device model swap before the battle, or run
      cloud Gemini and disclose that honestly in the demo (see AGENTS.md: never claim
      offline/on-device unless true).
- [ ] Set the Gemini API key in `lib/screens/constapi.dart` (from `.example`).
- [ ] Build the release APK and test on the loaner iQOO phone.
- [ ] Practice the Office Kit pairing flow (screen mirror, file transfer, remote
      control) ahead of the Saturday 10:00 teach-in.
- [ ] Prepare non-sensitive demo props (medicine strip, notice, bill) per AGENTS.md
      safety rules — no real personal data.
- [ ] Rehearse the failure branches, not just the happy path: model timeout →
      Volume-Down repeat, permission denial, offline recognizer failure.
- [ ] Pack: laptop, charger, power bank, USB-C cable.

---

## Earlier internal pitch draft (unverified, historical)

The sections below were written before this project's actual feature status was
tracked in PROJECT.md. Several described features (wake-word activation,
shake-to-activate, 25+ voice commands, full Tamil voice support, a bundled Gemma
TFLite model) are **not currently true of this codebase** — see the alignment table
above and PROJECT.md's feature register for what is actually implemented and
verified. Kept only for historical reference; do not quote this section to judges.

### Original demo flow (2 minutes) — as originally drafted, not current

```
1. Open app → Camera loads with GPS accuracy badge (green = ≤10m)
2. Say "Hey Assistant" → Voice assistant activates
3. Say "Take photo" → Captures image in current mode
4. Say "Describe scene" → AI describes with GPS context
5. Say "Switch to food mode" → Changes to food labels
6. Say "Identify food" → Captures + analyzes nutrition/allergens
7. Say "Read text" → OCR mode for documents/signs
8. Say "Where am I" → Announces address + GPS coordinates
9. Say "Search weather Chennai" → Live web search + AI summary
10. Switch to Tamil → Full UI + voice in Tamil
11. Disconnect WiFi → Still works with cached responses
12. Shake phone → Toggles wake word listening
13. Double-tap → Debug overlay (FPS, GPS, cache, network, model)
14. Enable High Contrast + Large Text → Full accessibility demo
```

For the current, real demo script use `VIDEO_DEMO_SCRIPT.md` and DEMO_SETUP.md
instead.

### Original judging-criteria guess — not organizer material

| Criteria (weight guessed) | Notes |
| --- | --- |
| End Product Quality | Unverified guess from an earlier draft, not from City Battles organizer material. |
| Novelty & Impact | Same. |
| Creative Phone Use | Same. |
| Technical Depth | Same. |
| Office Kit Usage | Same. |
| Demo & Presentation | Same. |

---

## Contact
Built for iQOO City Battles 2026, Chennai battle
**Innovation**: audio-first assistant for blind and low-vision users, built around a
two-stage OCR + language-model pipeline.
