"""Section 6 live-server check: run tools/live_check.luau in a REAL Roblox server of the place
(Open Cloud Luau Execution) and report every animation and sound that does not load there, plus the
game's own server boot line from the task's logs. Writes work/live_check.json.

    python tools/live_check.py [--version N]

Needs the key scope luau-execution-sessions:write. The key is read from ROBLOX_API_KEY, never printed.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = "https://apis.roblox.com/cloud/v2"


def call(method: str, url: str, key: str, body: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"x-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", type=int, default=None)
    a = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    game = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))
    universe, place = game["publish"]["universe_id"], game["publish"]["place_id"]
    base = f"{API}/universes/{universe}/places/{place}"
    if a.version:
        base += f"/versions/{a.version}"
    script = (ROOT / "tools" / "live_check.luau").read_text(encoding="utf-8")
    status, task = call("POST", f"{base}/luau-execution-session-tasks", key,
                        {"script": script, "timeout": "300s"})
    if status != 200:
        print("create failed", status, task)
        return 1
    path = task["path"]
    print("task", path)
    deadline = time.time() + 330
    while time.time() < deadline:
        time.sleep(5)
        status, task = call("GET", f"{API}/{path}", key)
        state = task.get("state") if isinstance(task, dict) else None
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    print("state", task.get("state"))
    _, logs = call("GET", f"{API}/{path}/logs", key)
    lines = []
    for chunk in (logs.get("luauExecutionSessionTaskLogs") or []) if isinstance(logs, dict) else []:
        lines += chunk.get("messages") or []
    boot = [l for l in lines if "Server started" in l]
    print("boot line:", boot[:1] or "NOT FOUND")
    if task.get("state") != "COMPLETE":
        print("error:", task.get("error"))
        return 1
    results = (task.get("output") or {}).get("results") or []
    report = json.loads(results[0]) if results else {}
    report["bootLog"] = boot[:1]
    report["version"] = path.split("/versions/")[1].split("/")[0] if "/versions/" in path else None
    out = ROOT / "work" / "live_check.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report, indent=1), encoding="utf-8")
    anims, sounds = report.get("animations", {}), report.get("sounds", {})
    bad_a = {k: v for k, v in anims.items() if not str(v).startswith("ok")}
    bad_s = {k: v for k, v in sounds.items() if not str(v).startswith("ok")}
    print(f"version {report['version']}: animations {len(anims) - len(bad_a)}/{len(anims)} ok, "
          f"sounds {len(sounds) - len(bad_s)}/{len(sounds)} ok, boot {report.get('boot')}")
    for k, v in {**bad_a, **bad_s}.items():
        print("  FAIL", k, v)
    return 0 if not bad_a and not bad_s and boot else 1


if __name__ == "__main__":
    sys.exit(main())
