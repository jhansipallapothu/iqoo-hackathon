# Handoff — 2026-09-02

Where the project is after a long build session. Read `README.md` for
architecture, `DEMO_FEATURES.md` for the hackathon plan and demo script.

## Branch

Work is on `feature/blind-first-and-sms`. `main` has only the baseline commit.

```
6676d3f  Rewrite README for the current architecture
a19bfe2  Two-stage Read & Explain pipeline (OCR + streamed explanation)
b5eed21  Scope to English only, repitch on comprehension
897dae2  Emergency calling with a cancellable countdown
b96100c  Centralise TTS config, raise speech rate to 1.3
e8c1883  Fix startup jank + always-alive camera
b01889e  Blind-first interaction + SMS triage + hardware keys
4c1b1e8  Baseline: working cloud demo on Android          (main)
```

## Verified working (on the Redmi, earlier in the session)

Camera → GPS reverse-geocode → cloud Gemini (`gemini-3.6-flash`) description
→ spoken aloud. Settings screen, mode switching, response cache, debug overlay.

## Built but NEVER RUN on a device

The test phone (Redmi 10 Prime, `adb -s 10145e690506`) died mid-session.
Everything from `b01889e` onward is compile-checked and APK-build-checked only:

- Two-stage Read & Explain pipeline (ML Kit OCR + streamed explanation + cache)
- Volume keys (native `MainActivity.kt`), tap-anywhere / swipe / long-press
- Launch announcement, TTS rate 1.3
- SMS triage
- Startup-jank fix, camera preview suspend/resume
- **Emergency calling — places a real phone call. Test the CANCEL path first.**

## Next session — do these in order

1. **Charge the Redmi. `flutter run -d 10145e690506`.** Walk through the list
   above. This is the top priority — 8 feature commits with no device run.
2. **Point ML Kit at a real medicine strip.** Foil, 6pt type, curved. If it
   can't read that, the medicine demo needs a different prop — find out now,
   not on Sept 12.
3. **Test emergency:** Settings → set contact to your own 2nd number →
   long-press the viewfinder → confirm a tap cancels the countdown → then
   let one call through.
4. Fix whatever breaks. Commit per fix.

## Sept 4 — the on-device spike (not started)

`ai_service.explain()` is the seam. Swap cloud Gemini for `flutter_gemma` +
Gemma 2B. Before committing to it, measure on the iQOO 15 (or any Snapdragon
phone):

- `.npu` vs `.gpu` vs `.cpu` backend latency (NNAPI was >4200ms vs ~500ms CPU
  in arXiv 2607.02371 — do not assume NPU wins)
- peak RAM with the model loaded + camera running
- check Qualcomm AI Hub for pre-optimised Snapdragon weights

## Known constraints

- Impeller off (`EnableImpeller=false` in manifest) — black-screens old Mali GPUs
- `speech_to_text` does not init on the Redmi's MIUI (stub recogniser) —
  expected to work on the iQOO 15
- `en-IN` TTS is a network-only voice on Indian devices — everything uses `en-US`
- `lib/screens/constapi.dart` is gitignored; copy from `.example` and add a key
- Commit with `git -c core.autocrlf=false` to avoid CRLF churn
- `HACKATHON_README.md` is stale (pre-session, describes the fake on-device LLM) —
  delete it or replace with a pointer to README + DEMO_FEATURES
