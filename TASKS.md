# Next-session tasks

Ordered. Commit per fix (`git -c core.autocrlf=false`). See `HANDOFF.md` for
context, `DEMO_FEATURES.md` for the demo script.

## P0 — device verification (Redmi, `flutter run -d 10145e690506`)

- [ ] **OCR a real medicine strip** (foil, ~6pt, curved) and a printed notice.
      Confirm the slow-path `explain()` fires and the spoken answer names the
      dose limit / expiry / required action. If OCR can't read foil print,
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

## P0 — iQOO 15 only (voice input is dead on the Redmi)

- [ ] `speech_to_text` initialises → double-tap-to-ask works (speak a question,
      it captures and answers *that*).
- [ ] Explore voice chat loop: speak → transcribe → answer spoken → mic
      re-opens; toggle off stops it.

## P1 — Sept 4 on-device spike

- [ ] Swap `ai_service.explain()` cloud Gemini → `flutter_gemma` + Gemma 2B.
- [ ] Measure `.npu` / `.gpu` / `.cpu` latency, peak RAM with model + camera.
- [ ] Check Qualcomm AI Hub for pre-optimised Snapdragon weights.
- [ ] Keep the template fallback — if the model stalls, OCR must still answer.

## P2 — polish / cleanup

- [ ] Physically strip the dead `isTamil ? … : …` ternaries (English-only now).
- [ ] Delete or replace stale `HACKATHON_README.md`.
- [ ] Move the GPS accuracy badge into the debug overlay only.
- [ ] Separate the top-bar status icons (online/GPS) from the settings action.
- [ ] `flutter build apk --release --split-per-abi` still green.
- [ ] Rehearse the 90-sec script incl. the "model stalled → Vol-Down repeats"
      failure branch.
