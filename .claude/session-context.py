#!/usr/bin/env python3
"""SessionStart hook: inject AIFORALL working context so every new session
starts having read HANDOFF.md, TASKS.md, and the project memory files."""
import glob
import json
import os

PROJ = r"C:\Users\BOSON-229\Documents\one pease\AIFORALL-main\AIFORALL-main"
MEM = r"C:\Users\BOSON-229\.claude\projects\C--Users-BOSON-229-Documents-one-pease-AIFORALL-main-AIFORALL-main\memory"

files = [os.path.join(PROJ, "HANDOFF.md"), os.path.join(PROJ, "TASKS.md")]
files += sorted(glob.glob(os.path.join(MEM, "*.md")))

parts = []
for p in dict.fromkeys(files):
    try:
        with open(p, encoding="utf-8") as fh:
            parts.append(f"=== {os.path.basename(p)} ===\n{fh.read().strip()}")
    except OSError:
        pass

ctx = (
    "AIFORALL working context. Read this before starting — it is the current "
    "state of the project, the next-session task list, and the persistent "
    "memory.\n\n" + "\n\n".join(parts)
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    }
}))
