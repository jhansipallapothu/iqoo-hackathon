---
name: device-run
description: Rebuild AIFORALL, install on the Redmi test phone, wait for launch, and grab a screenshot. Use when asked to run the app on the device, retest a change on hardware, or "screenshot the app".
disable-model-invocation: true
---

# device-run

Runs the app on the physical test phone and captures a screenshot. This is the
loop used constantly during device testing — rebuild, reinstall, relaunch,
look.

## Constants

- Flutter: `C:\src\flutter\bin\flutter.bat` (PowerShell) — the plain `flutter`
  may not be on PATH in a fresh shell.
- adb: `C:\Users\BOSON-229\AppData\Local\Android\sdk\platform-tools\adb.exe`
- Device serial: `10145e690506` (Redmi 10 Prime, `21061119BI`)
- Screenshot dir: the session scratchpad (`.../scratchpad/`)

## Steps

1. If a previous `flutter run` background task is still attached, stop it first
   (a second `flutter run` fails to install over an attached session).

2. Launch in the background and tee to a log:
   ```
   C:\src\flutter\bin\flutter.bat run -d 10145e690506 2>&1 | Tee-Object -FilePath <scratchpad>/run.log
   ```
   First build pulls native ML Kit (~40-60 s Gradle). Incremental is faster.

3. Wait for the launch line (poll the log, don't sleep blindly):
   ```
   grep -q "Dart VM Service on" <scratchpad>/run.log
   ```
   `BUILD FAILED` / `FAILURE:` / `e: ` (Kotlin) in the log means stop and report
   the error instead.

4. Screenshot:
   ```
   adb -s 10145e690506 exec-out screencap -p > <scratchpad>/s.png
   ```
   Then Read the PNG.

5. To drive the UI over adb while watching:
   - `adb -s 10145e690506 shell input keyevent 24` — Volume-Up (capture)
   - `adb -s 10145e690506 shell input keyevent 25` — Volume-Down (repeat)
   - `adb -s 10145e690506 shell input tap X Y` — tap
   - `adb -s 10145e690506 shell input swipe X Y X Y 1200` — long-press (SOS)
   - `adb -s 10145e690506 shell dumpsys window | grep mCurrentFocus` — which screen

## Gotchas

- MIUI blocks `adb install` unless Developer options -> Install via USB is ON.
- `speech_to_text` does not init on this phone (MIUI stub recogniser) — voice
  input features announce "not available" here; test them on the iQOO 15.
- A static change (e.g. `SpeechConfig.rate`) needs a full restart, not hot
  reload — stop the run and start a new one.
- `lib/screens/constapi.dart` is gitignored; if missing, copy from
  `constapi.dart.example` and add the Gemini key.
