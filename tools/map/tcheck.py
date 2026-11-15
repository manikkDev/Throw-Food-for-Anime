"""Run only the terrain checks on design/map.json (fast iteration; prove.py is the authority)."""
import json, os, sys
from types import SimpleNamespace
sys.path.insert(0, os.path.join(os.path.expanduser("~"), ".claude", "skills", "roblox-map", "scripts"))
import terrain as T, checks_terrain as CT, spec as S
from prove import Check
spec = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "design", "map.json"), encoding="utf-8"))
t = T.generate(spec, None, preview=False)
C = SimpleNamespace(Check=Check, PASS="PASS", FAIL="FAIL", WARN="WARN", INFO="INFO")
for c in CT.run(t, spec, S.load_profile("default"), C):
    print(f"[{c.status}] {c.id} {c.detail}")
    for r in c.rows[:4]: print("     -", r)
