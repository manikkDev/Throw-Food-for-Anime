#!/usr/bin/env python3
"""Measure sound candidates in a running Studio play session (they do not play in edit mode).

    python tools/studio/sfx_probe.py assets/sfx/candidates_phase_d.json [--out work/sfx/probe_d.json]

For every candidate id of every role it loads the sound on the Client datamodel at a volume nobody
hears (0.008) and samples Sound.PlaybackLoudness for up to 3.5 s, then writes per id:
  loaded, length (the real TimeLength), peak, lead (seconds before it reaches 10% of its peak),
  peak_at, body (seconds above 25% of the peak), events (separate bursts), tail (seconds from the
  last sample above 25% to the end of the window)
The picks are made by hand from those numbers (a hit: fast attack, one event, short body).
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"

LUAU = r'''
local ids = {IDS}
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local store = workspace:FindFirstChild("SfxProbe") or Instance.new("StringValue")
store.Name = "SfxProbe"
store.Value = ""
store.Parent = workspace
local results = {}
local running = 0
local function probe(id)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = 0.008
	sound.Parent = SoundService
	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < 5 do
		task.wait(0.05)
	end
	local row = { id = id, loaded = sound.IsLoaded, length = sound.TimeLength }
	if sound.IsLoaded and sound.TimeLength > 0 then
		local window = math.min(sound.TimeLength, 3.5)
		local samples = {}
		sound:Play()
		local s0 = os.clock()
		while os.clock() - s0 < window do
			table.insert(samples, { os.clock() - s0, sound.PlaybackLoudness })
			RunService.Heartbeat:Wait()
		end
		sound:Stop()
		local peak, peakAt = 0, 0
		for _, s in samples do
			if s[2] > peak then
				peak, peakAt = s[2], s[1]
			end
		end
		local lead, body, events, last, on = nil, 0, 0, 0, false
		for i, s in samples do
			if not lead and s[2] >= peak * 0.1 then
				lead = s[1]
			end
			local hot = s[2] >= peak * 0.25
			if hot then
				local dt = if i > 1 then s[1] - samples[i - 1][1] else 0
				body += dt
				last = s[1]
			end
			if hot and not on then
				events += 1
			end
			on = hot
		end
		row.peak = math.floor(peak)
		row.peak_at = math.floor(peakAt * 100) / 100
		row.lead = math.floor((lead or 0) * 100) / 100
		row.body = math.floor(body * 100) / 100
		row.events = events
		row.tail = math.floor((window - last) * 100) / 100
	end
	sound:Destroy()
	results[tostring(id)] = row
end
task.spawn(function()
	for _, id in ids do
		while running >= 6 do
			task.wait(0.1)
		end
		running += 1
		task.spawn(function()
			pcall(probe, id)
			running -= 1
		end)
	end
	while running > 0 do
		task.wait(0.2)
	end
	store.Value = game:GetService("HttpService"):JSONEncode(results)
end)
return "probing " .. #ids
'''

READ = 'local s = workspace:FindFirstChild("SfxProbe") return if s then s.Value else ""'


def luau(code: str) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as tmp:
        tmp.write(code)
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Client", "--file", tmp.name], capture_output=True, text=True,
                         encoding="utf8", errors="replace")
    return (out.stdout + out.stderr).strip()


def main() -> int:
    src = Path(sys.argv[1])
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else Path("work/sfx/probe.json")
    roles = json.loads(src.read_text(encoding="utf-8"))["roles"]
    ids = sorted({int(c["id"]) for rows in roles.values() for c in rows})
    print(luau(LUAU.replace("{IDS}", "{" + ", ".join(map(str, ids)) + "}")))
    deadline = time.time() + 240
    raw = ""
    while time.time() < deadline:
        time.sleep(8)
        raw = luau(READ)
        if raw.startswith("{"):
            break
    if not raw.startswith("{"):
        print("no result:", raw[:200])
        return 1
    measured = json.loads(raw)
    report = {role: [{**c, **measured.get(str(c["id"]), {})} for c in rows] for role, rows in roles.items()}
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=1), encoding="utf-8")
    for role, rows in report.items():
        print(role)
        for c in rows:
            print(f"  {c['id']:>16} {str(c.get('loaded')):5} len {c.get('length', 0):6.2f} peak {c.get('peak', 0):4} lead {c.get('lead', 0):4} "
                  f"at {c.get('peak_at', 0):4} body {c.get('body', 0):4} ev {c.get('events', 0)} tail {c.get('tail', 0):4}  {c['creator'][:16]:16} {c['name'][:44]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
