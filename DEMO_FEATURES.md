# AI For ALL — iQOO Hackathon 2026 (Chennai) Feature List

**Product:** On-device visual assistant for blind / low-vision users.
**Rule fit:** All reasoning runs as a local model on-device (**Gemma 3n E4B** via `flutter_gemma`; see *On-device model plan* below). Internet is allowed and used only to pull in live data — never for LLM inference.

---

## Core — live on stage, all reasoning on the NPU

1. **Scene description** — point the camera, Gemma 3n E4B describes what's in front of you, spoken aloud.
2. **Text reading** — point at a sign, label, menu, or letter → reads the text aloud.
3. **Follow-up Q&A** — "is there a door on the left?", "what colour is the bus?" — local model answers, grounded on what it just saw.
4. **Voice-first, eyes-free** — Gemma 3n handles audio input natively (no separate ASR), TTS for every response. No screen touch needed.

## Internet-augmented — web fetches the data, the local model turns it into one spoken answer

5. **Location awareness** — GPS + reverse geocode: "where am I", "what's nearby", walking directions read aloud.
6. **Live info lookup** — weather, opening hours, prices, news: fetched from the web, summarised on-device into a single sentence.
7. **Product / label lookup** — scan a barcode or label → fetch product + allergen / nutrition info → local model explains it plainly.

## Supporting — shown briefly

8. **Accessibility UI** — large text, high contrast, full screen-reader semantics, haptic feedback.
9. **Tamil + English** — UI, voice input, and TTS output.
10. **Graceful offline mode** — scene description, text reading, and Q&A keep working with no connectivity; only the live-data features pause.

## Creative phone use — for the 15% HackTracker criterion

11. **Shake-to-activate** — wake the assistant hands-free.
12. **One flow uses camera + mic + accelerometer + GPS + haptics + barcode** together.

## Office Kit — for the 10% tracked criterion (pitch mention)

13. Used in Green Light to push the model file + assets to the phone and screen-mirror for debugging.

## Roadmap — one slide, not demoed

- Dementia memory support (on-device face + place recognition).
- Hands-free productivity assistant.
- Same on-device vision + voice core.

---

## The proof moment (20 seconds in the demo)

Toggle **airplane mode mid-demo**: scene description, text reading, and Q&A keep working (local model on NPU); only weather / nearby degrade. Shows judges exactly what runs on-device vs. what is just internet plumbing.

## Cut — and say so

| Cut | Why |
| --- | --- |
| Cloud LLM (Gemini / OpenAI) for any reasoning | -25% risk; the model must be local |
| Auth / login / wifi-connect screens | dead weight |
| Separate "food mode" / "document mode" screens | folded into scene + text + label lookup |
| 25+ voice commands | keep ~6 you'll actually say on stage |

## Pitch one-liner

> "AI For ALL turns the iQOO 15 into a talking pair of eyes — scene and text description running entirely on the Snapdragon NPU, using the internet only to pull in live details like weather or a product's allergens. The understanding never leaves the phone."

---

## On-device model plan (decided from research, Sept 2026)

**Device provided:** iQOO 15 — Snapdragon 8 Elite Gen 5, Hexagon NPU (~80 TOPS, INT2–FP16), **12–16 GB LPDDR5X**, 7000 mAh. Models are **not** pre-installed; we bring them.

**Primary: Gemma 3n E4B** via `flutter_gemma` (LiteRT-LM). Chosen because:

- Multimodal — **image + audio + text in one model**, so it covers scene description, text reading, *and* voice input (no separate Whisper).
- ~4B effective params, ~4.5 GB int4 — needs ~8 GB RAM, and the iQOO 15 has 12–16 GB. The RAM headroom is exactly why E4B is affordable here where it wouldn't be on a mid-range phone.
- Pretrained across 140 languages → best small-model shot at Tamil.
- Best-documented Flutter path; one dependency for the whole on-device stack.

**Known risk: latency.** E4B is ~8–15 s per image on flagship hardware. That is too slow for "point and hear" if it holds. Mitigation ladder, decided by measurement on Sept 4:

| Tier | Model | Size | ~Latency | When to use |
| --- | --- | --- | --- | --- |
| 1 | **Gemma 3n E4B** | ~4.5 GB | 8–15 s | If NPU-accelerated and ≤8 s — best quality, ship it |
| 2 | **Gemma 3n E2B** | ~3 GB | 3–8 s | If E4B is too slow. Same capabilities, smaller |
| 3 | **SmolVLM-500M** | ~0.6 GB | ~7 s | If both 3n variants fail to load/accelerate |
| 4 | **Florence-2** (caption + OCR tasks) | ~0.5 GB | <1 s | Text-reading mode specifically — a real OCR model beats an LLM guessing at text |

**Must verify in the Sept 4 spike (do not assume):**

1. Does `flutter_gemma` actually place Gemma 3n on the **Hexagon NPU**, or silently fall back to GPU/CPU? NPU support for 3n on 8 Elite is still maturing.
2. **Benchmark all three backends** — `PreferredBackend.npu` / `.gpu` / `.cpu`. The VisionAId paper measured NNAPI at >4200 ms vs ~500 ms CPU on some chipsets because of unsupported ops. NPU is not automatically faster.
3. Check **Qualcomm AI Hub** for pre-optimised Snapdragon weights before quantising anything ourselves.
4. Peak RAM during inference — E4B on a 12 GB loaner with the camera pipeline also running is not guaranteed.

**Fallback that stays honest:** on-device primary + cloud Gemini fallback, with a visible indicator of which one answered. Do not claim "runs on the NPU" in the pitch until step 1 is measured.

**Pre-event:** download E4B, E2B, SmolVLM-500M and Florence-2 to a USB stick (~9 GB total). Venue wifi will not carry this.

---

## Judging criteria map (reference)

| Criterion | Weight | Covered by |
| --- | --- | --- |
| End product quality | 30% | Core 1–4 working cleanly, small scope |
| Novelty & impact | 20% | Accessibility for blind users, offline-capable, Tamil-first |
| Creative phone use | 15% | Features 11–12, NPU use, airplane-mode proof |
| Technical depth | 15% | Real on-device VLM + ASR pipeline on the NPU |
| Office Kit usage | 10% | Feature 13 |
| Demo & presentation | 10% | Airplane-mode proof moment, one-liner, ~6 rehearsed commands |
