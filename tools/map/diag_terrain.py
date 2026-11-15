"""Where are the steep columns and what are the gentle levels? (diagnostic only)"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.expanduser("~"), ".claude", "skills", "roblox-map", "scripts"))
import terrain as T
spec = json.load(open("design/map.json", encoding="utf-8"))
t = T.generate(spec, None, preview=False)
h = t["height"]; g = t["meta"]["grid"]
gz, gx = np.gradient(h, 4.0)
sl = np.degrees(np.arctan(np.hypot(gx, gz)))
land = h >= -3
steep = sl >= 45
zz, xx = np.nonzero(steep)
X = g["x0"] + (xx + .5) * 4; Z = g["z0"] + (zz + .5) * 4
print("steep>=45:", steep.sum())
H, xe, ze = np.histogram2d(X, Z, bins=[np.arange(-400, 401, 80), np.arange(-1520, 1521, 160)])
for j in range(H.shape[1]):
    row = " ".join(f"{int(v):4d}" for v in H[:, j])
    if H[:, j].sum(): print(f"z {ze[j]:6.0f}: {row}")
gent = h[land & (sl < 14)]
hist, edges = np.histogram(gent, bins=np.arange(gent.min(), gent.max() + 6, 6))
need = land.sum() * 0.015
print("land cols", land.sum(), "need/bin", int(need))
for c, e in zip(hist, edges):
    print(f"{e:6.1f} {c:6d} {'ON' if c >= need else ''}")
