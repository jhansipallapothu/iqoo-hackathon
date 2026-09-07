# Next-session tasks

Ordered. Commit per fix (`git -c core.autocrlf=false`). See `HANDOFF.md` for
context, `DEMO_FEATURES.md` for the demo script.

## P0 — device verification (Redmi, `flutter run -d 10145e690506`)

- [ ] **OCR a real medicine strip** (foil, ~6pt, curved) and a printed notice.
      Confirm the slow-path `explain()` fires and the spoken answer names the
      only details present in the captured text; missing dose/expiry/action details must not be invented. If OCR can't read foil print,
      the medicine demo needs a different prop — decide now.
- [ ] **Emergency, full re-test** (commit `1beafa8` reworked it):
  - set contact to a safe 2nd number in Settings
  - long-press → tap *during* the spoken "your location is…" preamble → must abort, no call
  - long-press twice quickly → must not double-dial
  - let one countdown complete → confirm the call actually connects
- [ ] **First-run tutorial**: clear-data install → 7 spoken steps, tap = next,
      swipe = skip; last step opens the assistant picker. Set AIFORALL as the
      device Assistant, confirm power-button-hold launches it and it speaks
      "ready".
- [ ] Vol-Down = repeat last answer; swipe L/R = mode switch with spoken name.
- [ ] Confirm speech rate 0.4 is comfortable; adjust `SpeechConfig.rate` if not.
- [ ] SMS triage (send the phone an OTP / spam / txn SMS, check it's read).

## P0 — Message assistant + fraud protection (building now)

- [x] `classifySms` → add `SmsRisk` (none/caution/danger) + `fraudWarning`.
      Offline rules: link + bank/urgency words, OTP that also has a link or
      "share"/"call", urgency + link/number, refund/prize + link. Self-check.
- [x] `InboxScreen` — reads the inbox via `another_telephony` `getInboxSms`,
      classifies each, speaks sequentially (`awaitSpeakCompletion(true)`).
      Per message: ~2.5 s window, double-tap = mark important (spoken
      "Marked important" / else "Left unmarked"). Flags persist in
      `OfflineCacheService` (`msg_imp_<key>`). After the pass: double-tap =
      replay only the important ones. Single tap / Vol key = repeat last line.
- [x] Danger message: speak the warning first; do NOT read the OTP digits or
      the URL aloud (say "a code" / "a web link").
- [x] Entry point: labelled AppBar action on homepage ("Read my messages").
      Revisit if a gesture frees up.
- [ ] **Device-verify on the Redmi**: seed inbox with an OTP, a txn alert, a
      fake-bank scam SMS with a link. Confirm order, the double-tap window is
      long enough, flags survive re-open, danger message is redacted.
- [ ] Wire "read my messages" into the voice-assistant intent list (iQOO 15).

## P0 — iQOO 15 only (voice input is dead on the Redmi)

- [ ] `speech_to_text` initialises → double-tap-to-ask works (speak a question,
      it captures and answers *that*).
- [ ] Explore voice chat loop: speak → transcribe → answer spoken → mic
      re-opens; toggle off stops it.

## P1 — Sept 4 on-device spike

- [x] Swap `ai_service.explain()` cloud Gemini → `flutter_gemma` + on-device
      model. Done 2026-09-07: wired `flutter_gemma`/`flutter_gemma_litertlm`
      running **Qwen3 0.6B** (not Gemma — team chose the ungated public model
      to avoid a Hugging Face token/license step during the live event).
      `minSdkVersion` raised to 30 (plugin requirement). `flutter analyze` and
      `flutter build apk --release` pass; not yet run on a physical device.
- [ ] Device-verify on the loaner iQOO phone: confirm the ~586MB first-run
      download completes, confirm `PreferredBackend.npu` actually engages
      (check via debug overlay / logs, not just requested), measure latency
      and peak RAM with model + camera both active.
- [ ] Confirm airplane-mode behavior after the first successful download.
- [ ] Keep the template fallback — if the model stalls, OCR must still answer
      (unchanged: `AiService.explain()` falls through to cloud, and
      `read_explain_screen.dart`'s template fallback is untouched by this
      change).

## P2 — polish / cleanup

- [x] Physically strip the dead `isTamil ? … : …` ternaries (English-only now). Done 2026-09-07: removed `isTamil`/Tamil strings across lib/, `tamil_support`/`wake_word_ta` from config models and JSON, and deleted `assets/l10n/ta.json`.
- [ ] Delete or replace stale `HACKATHON_README.md`.
- [ ] Move the GPS accuracy badge into the debug overlay only.
- [ ] Separate the top-bar status icons (online/GPS) from the settings action.
- [ ] `flutter build apk --release --split-per-abi` still green.
- [ ] Rehearse the 90-sec script incl. the "model stalled → Vol-Down repeats"
      failure branch.
