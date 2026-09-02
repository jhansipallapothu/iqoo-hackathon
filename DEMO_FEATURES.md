# AI For ALL — iQOO Hackathon 2026 (Chennai) Plan

**User:** blind and low-vision people (also serves low-literacy and elderly users — same flow, no extra build).

**What it does that Lookout / Seeing AI / Be My Eyes do not:** they *read text aloud*. We **explain what it means and what to do next** — on-device, offline, in Tamil or English.

> Point at a medicine strip → *"Crocin 650. Paracetamol, for fever and pain. Maximum four tablets a day. Expires January 2026."*
>
> Point at a ration-shop notice → *"New ration card applications open September 20. Bring Aadhaar and an income certificate to the office."*

Reading the label is the easy half. Knowing you must not exceed four tablets is the half that matters, and nobody ships it offline.

---

## Two-stage architecture (the core design decision)

A single big multimodal model means 8–15 s of silence and one point of failure. Instead, two paths run from one capture:

| | Fast path | Slow path |
| --- | --- | --- |
| **Does** | extract the text verbatim | explain it in plain language |
| **Uses** | **ML Kit OCR** (on-device, bundled) | **Gemma 2B** (on-device, on the organisers' supported list) |
| **Latency** | ~100–300 ms | 2–6 s, streamed |
| **Speaks** | immediately: *"Crocin 650mg, expiry 01/2026."* | continues: *"This is paracetamol, for fever…"* |

**Why this wins:** first audio in under a second, so the app always feels instant. And it has a floor — if the LLM stalls, crashes, or OOMs, OCR has *already spoken the answer*. The demo cannot go silent.

**Rules:**
- TTS starts on the first complete sentence, never waits for the full generation.
- LLM slower than ~6 s → speak a rule-based template over the OCR text and move on.
- Cache by image hash, so a repeat capture answers instantly.
- Volume-Down always re-speaks the last answer — manual recovery at any moment.

---

## Model plan

**Primary (build this): ML Kit OCR + Gemma 2B via `flutter_gemma`.**
Both on-device. Gemma 2B is explicitly named by the organisers as supported, is ~1.5 GB, and is far less likely to OOM on a hot loaner than a 4.5 GB multimodal model.

**Stretch (only if the spike proves it): Gemma 3n E4B.** Multimodal, would let us describe arbitrary scenes rather than only text. ~4.5 GB, needs ~8 GB RAM, 8–15 s per image. The iQOO 15's 12–16 GB makes it *possible*, not *safe*. Attempt only after the primary path works end to end.

**Fallback ladder if Gemma 2B underperforms:** Phi-3-mini (also supported) → SmolVLM-500M (~0.6 GB, ~7 s) → pure OCR with rule-based templates (still a working product).

### Sept 4 spike — measure, do not assume

1. Does `flutter_gemma` actually place Gemma 2B on the **Hexagon NPU**, or silently fall back to GPU/CPU?
2. **Benchmark `.npu` / `.gpu` / `.cpu`.** The VisionAId paper (arXiv 2607.02371) measured NNAPI at >4200 ms vs ~500 ms CPU-only on some chipsets — unsupported operators. NPU is not automatically faster.
3. **ML Kit OCR accuracy on Tamil script**, on a printed notice, under normal phone lighting. Tamil is supported; real-world accuracy is the open question.
4. Peak RAM with the model loaded *and* the camera pipeline running.
5. Check **Qualcomm AI Hub** for pre-optimised Snapdragon weights before quantising anything ourselves.

Do not write "runs on the NPU" in the pitch until step 1 is measured. Say "on-device" until then.

---

## Honesty about what runs where

| Phase | Inference | Why |
| --- | --- | --- |
| **Phase 1 submission video (now)** | Cloud Gemini | Proves the flow and the UX. Labelled as the cloud prototype — no offline claims. |
| **Hackathon build (Sept 12–13)** | On-device ML Kit + Gemma 2B | The graded version. Airplane mode on stage. |

Never claim offline operation in the submission video. The claim becomes true at the event, and only after the spike confirms it.

---

## Blind-first interaction (built, needs device testing)

The user never sees the screen, so nothing depends on finding a control.

| Input | Action |
| --- | --- |
| **Tap anywhere** on the viewfinder | Capture |
| **Volume Up** | Capture |
| **Volume Down** | Repeat last spoken answer |
| **Swipe left / right** | Change mode (spoken confirmation) |
| **Hold power button** | Opens the app — registered as an Android ASSIST provider |
| TalkBack | Full semantics on every control |

On launch it speaks: *"AI For All ready. Tap anywhere to read something."*
Every action confirms by haptic **and** voice. Feedback is de-duplicated — never re-speak unchanged information.

**TTS tuning:** ~1.3× rate, slightly lowered pitch. Daily screen-reader users run speech fast, and a lower pitch keeps it distinct from nearby human voices. (Currently 0.5× — fix before the demo.)

---

## Modes — reduced to two

1. **Read & Explain** — medicine, notices, bills, forms, labels, signs. The primary mode; merges the old Text / Documents / Food Labels.
2. **Explore** — general scene description. Only meaningful with the Gemma 3n stretch goal; keep it out of the demo unless it works.

---

## Kept in the build, cut from the demo

Working code, real telemetry for the auto-measured "creative phone use" (15%), but not shown on stage — they dilute a 90-second story:

- Offline SMS triage (OTP / spam / transaction, read aloud)
- GPS reverse-geocode + accuracy badge
- Web-augmented lookups
- Response cache + debug overlay

---

## Scoring the auto-measured criteria

**Creative phone use (15%, HackTracker telemetry)** — exercise these *in normal testing*, not as theatre: camera, torch (low-light label capture), microphone, volume keys, accelerometer (shake to repeat), haptics, GPS at startup, ASSIST launch. All are already wired.

**Office Kit (10%, HackTracker telemetry)** — make it a habit, not a final step. Every 25–30 minutes of laptop time: screen-mirror to debug, shared clipboard for logcat lines and prompts, file transfer for APKs and model files, remote control to tap through a build.

---

## 90-second demo script

Assume one live failure. The fast path carries it.

**0:00–0:15** — *"Airplane mode is on. No cloud."* Hold the power button; the app opens as an Assist provider and speaks *"Ready. Point at a document or medicine."* Pick up a medicine strip.

**0:15–0:40** — Volume Up. Haptic + shutter fire instantly. OCR speaks within a second: *"Crocin 650mg. Expiry 01/2026."* Gemma 2B then streams: *"Paracetamol, for fever and pain. Maximum four tablets a day."*

**0:40–1:05** — A Tamil government notice. Volume Up. OCR reads the Tamil; the model simplifies it: *"Ration card applications open September 20. Bring Aadhaar and income proof."*
*If the model stalls here:* "The OCR answer was already spoken — Volume Down repeats the last safe answer. The user is never left in silence." **The failure becomes a feature demonstration.**

**1:05–1:20** — Shake to repeat. Note that every control is a physical gesture: no button to find, nothing to see.

**1:20–1:30** — *"Everything you heard ran on this phone. OCR, the language model, Tamil speech. No cloud, no Wi-Fi — so it works in a village with no connectivity. And it doesn't just read the label. It tells you what the label means."*

---

## Judging criteria map

| Criterion | Weight | Covered by |
| --- | --- | --- |
| End product quality | 30% | Two-stage architecture with a guaranteed floor; small scope, finished |
| Novelty & impact | 20% | Explains rather than reads; offline Tamil; medicine and government-notice comprehension |
| Creative phone use | 15% | Volume keys, ASSIST, shake, torch, haptics, camera, mic, GPS |
| Technical depth | 15% | On-device OCR + LLM pipeline, streaming TTS, timeout/fallback design, NPU benchmarking |
| Office Kit usage | 10% | Continuous use during Green Light |
| Demo & presentation | 10% | Airplane mode, high-stakes objects, rehearsed failure recovery |

---

## Pre-event checklist

- [ ] Sept 4: run the spike above; record real numbers
- [ ] Fix TTS rate 0.5 → 1.3× and add feedback de-duplication
- [ ] Build the two-stage pipeline; verify the fallback by killing the LLM deliberately
- [ ] Test ML Kit OCR on real Tamil printed material
- [ ] USB stick with Gemma 2B, Phi-3-mini, SmolVLM-500M, Gemma 3n E2B/E4B (~9 GB) — venue wifi will not carry this
- [ ] Verify `flutter build apk --release` (only debug tested so far)
- [ ] Find one blind tester for 20 minutes before Sept 12 — worth more than any feature
- [ ] Rehearse the 90-second script ten times, including the failure branch
