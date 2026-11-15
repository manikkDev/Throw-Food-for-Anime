#!/usr/bin/env python3
"""Bring every uploaded model into the place as a clean template the game and the map clone.

    python tools/studio/install_models.py            install everything in assets/meshes/ids.json
    python tools/studio/install_models.py --only Plot_Pedestal Coin_Yen

For each model: InsertService:LoadAsset(id), then
  * flatten it to ONE Model named <Name> holding its MeshParts (one per colour)
  * colour each part from the hex at the end of its name (measured 2026-11-14: an uploaded GLB
    arrives with the right size, one MeshPart per colour and the hex in the name, but every part
    is default grey: the colour does not survive the upload)
  * SmoothPlastic, anchored; the #FF00FF part is renamed "Accent" (the game recolours it)
  * turn it half a turn (Roblox's importer delivers glTF back to front) and put the pivot at the
    base centre with no rotation (foods: at their centre), so PivotTo stands it on the ground facing -Z
  * parent to ReplicatedStorage.Assets.Kit / .Gear / .Foods by name prefix
and compare the size in Studio with the size the manifest measured.

Studio must be open on the place and NOT in Play. Safe to re-run: a template is replaced.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
MESHES = ROOT / "assets" / "meshes"
HELPER = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"

LUAU = r'''
local LIST = __LIST__
local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")

local function folder(parent, name)
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new("Folder")
		found.Name = name
		found.Parent = parent
	end
	return found
end
local assets = folder(RS, "Assets")
local stray = workspace:FindFirstChild("TFA_LoadTest")
if stray then
	stray:Destroy()
end

workspace:SetAttribute("TFAInstall", "running 0/" .. #LIST)
task.spawn(function()
	local report = {}
	for i, row in LIST do
		local ok, container = pcall(function()
			return InsertService:LoadAsset(row.id)
		end)
		if not ok then
			table.insert(report, "FAIL " .. row.name .. ": " .. tostring(container))
			continue
		end
		local model = Instance.new("Model")
		model.Name = row.name
		local parts, biggest, volume = 0, nil, 0
		for _, piece in container:GetDescendants() do
			if piece:IsA("MeshPart") then
				-- a model with two meshes of one colour arrives as Red_E0453C and
				-- Red_E0453C2: the trailing digit is Roblox's, not part of the hex
				local hex = string.match(piece.Name, "_(%x%x%x%x%x%x)%d?$")
				if hex then
					piece.Color = Color3.fromHex(hex)
					if string.upper(hex) == "FF00FF" then
						piece.Name = "Accent"
					end
				end
				piece.Material = Enum.Material.SmoothPlastic
				piece.Anchored = true
				piece.CanCollide = row.collide
				piece.CanTouch = false
				piece.CanQuery = row.collide
				piece.CastShadow = not row.food
				piece.Parent = model
				parts += 1
				local v = piece.Size.X * piece.Size.Y * piece.Size.Z
				if v > volume then
					biggest, volume = piece, v
				end
			end
		end
		container:Destroy()
		if parts == 0 then
			table.insert(report, "FAIL " .. row.name .. ": no MeshParts in the asset")
			continue
		end
		model.PrimaryPart = biggest
		local cf, size = model:GetBoundingBox()
		local centre = cf.Position
		-- Roblox's importer delivers a glTF model turned HALF A TURN about the vertical
		-- axis: a model authored with its front at -Z arrives with its front at +Z.
		-- MEASURED 2026-11-14 on Plot_ThrowStage: the arrow authored 1.1 studs toward +Z
		-- of the rim's centre sat 1.1 toward -Z in Studio, and every prop, sign and board
		-- in the first map faced away from the player. Turn it back here, once.
		local turn = CFrame.new(centre) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-centre)
		for _, piece in model:GetChildren() do
			if piece:IsA("BasePart") then
				piece.CFrame = turn * piece.CFrame
			end
		end
		-- The pivot is the base centre (foods: the centre) with NO rotation, so
		-- PivotTo(CFrame) puts the model on the ground facing -Z. A model with a
		-- PrimaryPart ignores WorldPivot, so the offset goes on the primary part.
		local base = if row.food then centre else centre - Vector3.new(0, size.Y / 2, 0)
		biggest.PivotOffset = biggest.CFrame:ToObjectSpace(CFrame.new(base))
		model:PivotTo(CFrame.new(0, 0, 0))
		model:SetAttribute("FrontIs", "-Z")
		model:SetAttribute("AssetId", row.id)
		local off = 0
		if row.bounds then
			for axis, want in { X = row.bounds[1], Y = row.bounds[2], Z = row.bounds[3] } do
				off = math.max(off, math.abs(size[axis] - want) / math.max(want, 0.01))
			end
		end
		local home = folder(assets, row.folder)
		local old = home:FindFirstChild(row.name)
		if old then
			old:Destroy()
		end
		model.Parent = home
		table.insert(report, string.format("%s %s parts=%d size=%.1f,%.1f,%.1f%s", if off > 0.05 then "SIZE" else "ok", row.name, parts, size.X, size.Y, size.Z, if off > 0.05 then string.format(" (%.0f%% off the manifest)", off * 100) else ""))
		workspace:SetAttribute("TFAInstall", "running " .. i .. "/" .. #LIST)
		if i % 4 == 0 then
			task.wait()
		end
	end
	workspace:SetAttribute("TFAInstall", "done\n" .. table.concat(report, "\n"))
end)
return "started"
'''


def manifest_rows() -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for manifest in sorted(MESHES.glob("manifest_*.json")):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            data = data.get("assets") or data.get("models") or data.get("entries") or list(data.values())
        for row in data:
            if isinstance(row, dict) and row.get("name"):
                rows[row["name"]] = row
    return rows


def luau_value(obj) -> str:
    if isinstance(obj, bool):
        return "true" if obj else "false"
    if isinstance(obj, (int, float)):
        return repr(obj)
    if isinstance(obj, str):
        return json.dumps(obj)
    if isinstance(obj, list):
        return "{" + ", ".join(luau_value(v) for v in obj) + "}"
    if isinstance(obj, dict):
        return "{" + ", ".join(f"{k} = {luau_value(v)}" for k, v in obj.items()) + "}"
    return "nil"


def studio(*args: str) -> str:
    done = subprocess.run([sys.executable, str(HELPER), "luau", "--dm", "Edit", *args],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (done.stdout + done.stderr).strip()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", nargs="*", default=None)
    a = ap.parse_args()

    ids = json.loads((MESHES / "ids.json").read_text(encoding="utf-8"))
    manifest = manifest_rows()
    rows = []
    for name, rec in sorted(ids.items()):
        if a.only is not None and name not in a.only:
            continue
        food, gear = name.startswith("Food_"), name.startswith("Equip_")
        bounds = (manifest.get(name) or {}).get("bounds_studs")
        rows.append({"name": name, "id": rec["assetId"], "food": food, "collide": not food,
                     "folder": "Foods" if food else "Gear" if gear else "Kit",
                     "bounds": bounds if isinstance(bounds, list) and len(bounds) == 3 else None})
    if not rows:
        print("nothing to install")
        return 0
    code = LUAU.replace("__LIST__", luau_value([{k: v for k, v in r.items() if v is not None} for r in rows]))
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "install.luau"
        script.write_text(code, encoding="utf-8")
        print(studio("--file", str(script)))
    result = ""
    for _ in range(120):
        time.sleep(2)
        result = studio("--code", "return workspace:GetAttribute('TFAInstall')")
        if result.startswith("done"):
            break
    studio("--code", "workspace:SetAttribute('TFAInstall', nil) return 'ok'")
    print(result)
    bad = [line for line in result.splitlines() if line.startswith(("FAIL", "SIZE"))]
    if not result.startswith("done") or bad:
        print(f"FAIL {len(bad)} model(s) need attention" if bad else "FAIL the install did not finish")
        return 1
    print(f"{len(rows)} template(s) installed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
