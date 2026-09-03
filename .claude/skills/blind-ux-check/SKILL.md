---
name: blind-ux-check
description: Accessibility guardrails for AIFORALL. Consult before adding or changing any screen, widget, or user interaction — this app is used entirely without sight.
user-invocable: false
---

# blind-ux-check

AIFORALL's users are blind or low-vision. The screen is never looked at.
Every interaction must work by feel, key, or voice, and every result must be
spoken. Apply this whenever touching UI or interaction code.

## Non-negotiables

1. **No control that must be found visually.** The whole camera preview is the
   shutter (tap anywhere). Actions map to physical inputs:
   - Tap anywhere = capture
   - Volume-Up = capture, Volume-Down = repeat last answer
   - Swipe left/right = change mode (spoken confirmation)
   - Long-press viewfinder = emergency (cancellable countdown)
   Hardware keys are handled natively in `MainActivity.kt` and also nudge
   `STREAM_MUSIC` so TTS loudness stays adjustable.

2. **Every action confirms by voice AND haptic.** `HapticFeedback.*` + a spoken
   line. Never a silent state change.

3. **Speech goes through `SpeechConfig`** (`lib/services/speech_config.dart`) —
   one rate/pitch/voice, `en-US` (en-IN is network-only on Indian devices).
   Don't call `setSpeechRate` / `setLanguage` anywhere else.

4. **TTS must not clip itself.** `flutter_tts` defaults to QUEUE_FLUSH — each
   `speak()` cancels the previous. For any sequence of utterances set
   `setQueueMode(1)` or `awaitSpeakCompletion(true)` and await each one.

5. **Semantics on every widget** — `Semantics(label:, button:, liveRegion:)`.
   Status text that changes is a `liveRegion`. Feedback is de-duplicated: never
   re-speak unchanged information.

6. **Audio-first, screen-second.** The screen still shows the OCR text /
   answer / thumbnail for a sighted helper or judge, but the product works with
   the screen off. A visual-only failure (blank body, black image) is a bug
   even though no user sees it.

7. **Never dial 112/108.** Emergency calls a user-set contact only, after a
   spoken cancellable countdown.

## When reviewing a change, check

- Can a blind user reach this without seeing it? How?
- Does it speak its result? Does it buzz?
- Could two utterances now collide?
- Is the new text a `liveRegion` if it updates?
- If speech recognition is involved: does it degrade gracefully when the
  recogniser is unavailable (announce, don't hang)?
