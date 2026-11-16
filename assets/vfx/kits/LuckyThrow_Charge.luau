-- LuckyThrow_Charge: roblox-vfx Studio kit (generated). Two halves:
--   M.buildTemplate(assets, parent)  EDIT MODE from the command bar / a plugin (sets MeshId + ColorMap)
--   M.spawn(origin, template) then M.play(h)  RUNTIME from a LocalScript (clones only)
-- assets = {textures = {["sim:x"] = "rbxassetid://N"}, meshes = {["sim:y"] = "rbxassetid://MESH_ID"}}
-- meshes need the MESH id (insert the uploaded model once and read .MeshId), not the model id.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local M = {NAME = "LuckyThrow_Charge", DURATION = 2}
M.NEEDS = {textures = {"sim:lib/sprites/stars/star_glow_04", "sim:lib/sprites/swirls/swirl_glow_03", "sim:tfa/clover_cel", "sim:tfa/clover_glow"}, meshes = {}}

local function tex(assets, id) local v = assets.textures[id]; if not v then warn("[LuckyThrow_Charge] missing texture " .. id) end; return v or "" end
-- emissive SurfaceAppearance properties differ between engine versions: try each spelling, report which failed once
M.PROP_FAILS = {}
local function soft(inst, prop, value) local ok = pcall(function() inst[prop] = value end); if not ok and not M.PROP_FAILS[inst.ClassName .. "." .. prop] then M.PROP_FAILS[inst.ClassName .. "." .. prop] = true; warn("[LuckyThrow_Charge] cannot set " .. inst.ClassName .. "." .. prop) end end
local function emissiveMask(sa, uri)
  if pcall(function() sa.EmissiveMaskContent = Content.fromUri(uri) end) then return end
  if pcall(function() sa.EmissiveMask = uri end) then return end
  if not M.PROP_FAILS.EmissiveMask then M.PROP_FAILS.EmissiveMask = true; warn("[LuckyThrow_Charge] no emissive mask property on SurfaceAppearance") end
end
local meshCache = {}
local function meshPart(assets, id)
  local uri = assets.meshes[id]
  if not uri then warn("[LuckyThrow_Charge] missing mesh " .. id); return Instance.new("Part") end
  if meshCache[uri] == nil then
    local ok, mp = pcall(function() return game:GetService("AssetService"):CreateMeshPartAsync(uri) end)
    meshCache[uri] = ok and mp or false
    if not ok then warn("[LuckyThrow_Charge] CreateMeshPartAsync failed for " .. id .. " (" .. uri .. "): " .. tostring(mp)) end
  end
  return meshCache[uri] and meshCache[uri]:Clone() or Instance.new("Part")
end

function M.buildTemplate(assets, parent)
  local folder = Instance.new("Folder"); folder.Name = M.NAME
  local I = {}   -- instances in a table: big kits (a shrine, a Susanoo) passed Luau's 200-local limit as locals
  I[0] = Instance.new("Part"); I[0].Name = "Shell"
  I[0]:SetAttribute("SimPath", "Shell")
  soft(I[0], "CFrame", CFrame.new(1.6, 3.2, -0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1))
  soft(I[0], "Size", Vector3.new(4.5, 4.5, 4.5))
  soft(I[0], "Transparency", 1)
  I[0].Anchored = true; I[0].CanCollide = false; I[0].CanQuery = false; I[0].CanTouch = false; I[0].CastShadow = false
  I[0].Parent = folder
  I[1] = Instance.new("ParticleEmitter"); I[1].Name = "Clovers"
  I[1]:SetAttribute("SimPath", "Shell.Clovers")
  soft(I[1], "Color", ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.7137, 1, 0.4196)), ColorSequenceKeypoint.new(1, Color3.new(0.2471, 0.8235, 0.3529))}))
  soft(I[1], "Enabled", true)
  soft(I[1], "Lifetime", NumberRange.new(0.55, 0.7))
  soft(I[1], "LightEmission", 0.25)
  soft(I[1], "LightInfluence", 0)
  soft(I[1], "Rate", 9)
  soft(I[1], "RotSpeed", NumberRange.new(-220, 220))
  soft(I[1], "Rotation", NumberRange.new(0, 360))
  soft(I[1], "Shape", Enum.ParticleEmitterShape.Sphere)
  soft(I[1], "ShapeInOut", Enum.ParticleEmitterShapeInOut.Inward)
  soft(I[1], "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
  soft(I[1], "Size", NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.2, 0.95, 0), NumberSequenceKeypoint.new(0.8, 0.8, 0), NumberSequenceKeypoint.new(1, 0, 0)}))
  soft(I[1], "Speed", NumberRange.new(3.5, 5))
  I[1].Texture = tex(assets, "sim:tfa/clover_cel")
  soft(I[1], "ZOffset", 0.5)
  I[1].Rate = 9
  I[1].Parent = I[0]
  I[2] = Instance.new("ParticleEmitter"); I[2].Name = "Motes"
  I[2]:SetAttribute("SimPath", "Shell.Motes")
  soft(I[2], "Color", ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(0.7137, 1, 0.4196))}))
  soft(I[2], "Enabled", true)
  soft(I[2], "Lifetime", NumberRange.new(0.4, 0.55))
  soft(I[2], "LightEmission", 0.7)
  soft(I[2], "LightInfluence", 0)
  soft(I[2], "Rate", 16)
  soft(I[2], "Rotation", NumberRange.new(0, 90))
  soft(I[2], "Shape", Enum.ParticleEmitterShape.Sphere)
  soft(I[2], "ShapeInOut", Enum.ParticleEmitterShapeInOut.Inward)
  soft(I[2], "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)
  soft(I[2], "Size", NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(0.3, 0.25, 0), NumberSequenceKeypoint.new(1, 0, 0)}))
  soft(I[2], "Speed", NumberRange.new(4, 6))
  I[2].Texture = tex(assets, "sim:lib/sprites/stars/star_glow_04")
  I[2].Rate = 16
  I[2].Parent = I[0]
  I[3] = Instance.new("Part"); I[3].Name = "Hand"
  I[3]:SetAttribute("SimPath", "Hand")
  soft(I[3], "CFrame", CFrame.new(1.6, 3.2, -0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1))
  soft(I[3], "Size", Vector3.new(1, 1, 1))
  soft(I[3], "Transparency", 1)
  I[3].Anchored = true; I[3].CanCollide = false; I[3].CanQuery = false; I[3].CanTouch = false; I[3].CastShadow = false
  I[3].Parent = folder
  I[4] = Instance.new("Attachment"); I[4].Name = "A"
  I[4]:SetAttribute("SimPath", "Hand.A")
  soft(I[4], "CFrame", CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1))
  I[4].Parent = I[3]
  I[5] = Instance.new("ParticleEmitter"); I[5].Name = "Swirl"
  I[5]:SetAttribute("SimPath", "Hand.A.Swirl")
  soft(I[5], "Color", ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.2471, 0.8235, 0.3529)), ColorSequenceKeypoint.new(1, Color3.new(0.2471, 0.8235, 0.3529))}))
  soft(I[5], "Enabled", true)
  soft(I[5], "Lifetime", NumberRange.new(0.6, 0.6))
  soft(I[5], "LightEmission", 0.6)
  soft(I[5], "LightInfluence", 0)
  soft(I[5], "Rate", 3)
  soft(I[5], "RotSpeed", NumberRange.new(-320, -320))
  soft(I[5], "Rotation", NumberRange.new(0, 360))
  soft(I[5], "Size", NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2, 0), NumberSequenceKeypoint.new(0.3, 1.9, 0), NumberSequenceKeypoint.new(1, 2.1, 0)}))
  soft(I[5], "Speed", NumberRange.new(0, 0))
  I[5].Texture = tex(assets, "sim:lib/sprites/swirls/swirl_glow_03")
  soft(I[5], "Transparency", NumberSequence.new({NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(0.25, 0.3, 0), NumberSequenceKeypoint.new(0.7, 0.4, 0), NumberSequenceKeypoint.new(1, 1, 0)}))
  soft(I[5], "ZOffset", -0.5)
  I[5].Rate = 3
  I[5].Parent = I[4]
  I[6] = Instance.new("ParticleEmitter"); I[6].Name = "Glow"
  I[6]:SetAttribute("SimPath", "Hand.A.Glow")
  soft(I[6], "Color", ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(0.7137, 1, 0.4196)), ColorSequenceKeypoint.new(1, Color3.new(0.2471, 0.8235, 0.3529))}))
  soft(I[6], "Enabled", true)
  soft(I[6], "Lifetime", NumberRange.new(0.5, 0.5))
  soft(I[6], "LightEmission", 0.5)
  soft(I[6], "LightInfluence", 0)
  soft(I[6], "Rate", 2.5)
  soft(I[6], "Rotation", NumberRange.new(-15, 15))
  soft(I[6], "Size", NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8, 0), NumberSequenceKeypoint.new(0.4, 1.25, 0), NumberSequenceKeypoint.new(1, 0.95, 0)}))
  soft(I[6], "Speed", NumberRange.new(0, 0))
  I[6].Texture = tex(assets, "sim:tfa/clover_glow")
  soft(I[6], "Transparency", NumberSequence.new({NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(0.3, 0.05, 0), NumberSequenceKeypoint.new(0.7, 0.2, 0), NumberSequenceKeypoint.new(1, 1, 0)}))
  soft(I[6], "ZOffset", 1)
  I[6].Rate = 2.5
  I[6].Parent = I[4]
  folder.Parent = parent
  return folder
end

-- opts (game mode, 2026-10-30 Awakened Arena): {game = true} keeps the caster's root under the game's physics,
-- {screen = false} drops the screen-space pieces (Lighting effects, the IF* impact-frame rig) so a move someone
-- else throws never grades or blanks this player's screen. No opts = the showcase behaviour, unchanged.
function M.spawn(origin, template, opts)
  origin = origin or CFrame.new()
  local f = template:Clone()
  local byPath, light, parts = {}, {}, {}
  for _, d in f:GetDescendants() do
    local p = d:GetAttribute("SimPath"); if p then byPath[p] = d end
    if d:IsA("BasePart") then table.insert(parts, d) end
    if d:GetAttribute("InLighting") then table.insert(light, d) end
  end
  for _, d in parts do d.CFrame = origin * d.CFrame end
  local screen = not (opts and opts.screen == false)
  if not screen then for _, d in f:GetDescendants() do if d.Name:sub(1, 2) == "IF" then byPath[d:GetAttribute("SimPath") or ""] = nil; d:Destroy() end end; for _, d in light do d:Destroy() end; light = {} end
  for _, d in light do d.Parent = Lighting end
  f.Parent = workspace
  return {folder = f, byPath = byPath, origin = origin, lighting = light, screen = screen, game = opts ~= nil and opts.game == true}
end

function M.preload(template)
  local list = {}
  local seen = {}
  for _, d in template:GetDescendants() do
    table.insert(list, d)
    if d:IsA("SurfaceAppearance") then for _, k in {"ColorMap", "EmissiveMask", "NormalMap", "MetalnessMap", "RoughnessMap"} do local ok, v = pcall(function() return d[k] end); if ok and typeof(v) == "string" and v ~= "" and not seen[v] then seen[v] = true; table.insert(list, v) elseif ok and typeof(v) == "Content" and v.Uri and not seen[v.Uri] then seen[v.Uri] = true; table.insert(list, v.Uri) end end end
    if d:IsA("MeshPart") then for _, k in {"MeshId", "TextureID"} do local v = d[k]; if v ~= "" and not seen[v] then seen[v] = true; table.insert(list, v) end end end
  end
  local failed = 0
  game:GetService("ContentProvider"):PreloadAsync(list, function(_, status) if status ~= Enum.AssetFetchStatus.Success then failed += 1 end end)
  return failed
end

M.ACTORS = {
}
M.FOLLOW = {}
local JOINTS = {"Torso", "Head", "RightArm", "LeftArm", "RightLeg", "LeftLeg"}
local LIMBS = {"RightArm", "LeftArm", "RightLeg", "LeftLeg"}
local function easeV(style, dir, a)
  if a <= 0 then return 0 elseif a >= 1 then return 1 end
  if style == "Constant" then return 0 end   -- a step key (hold until the key's time); not an Enum.EasingStyle (v4 probe: indexing it errored)
  local okS, es = pcall(function() return Enum.EasingStyle[style] end)
  local okD, ed = pcall(function() return Enum.EasingDirection[dir] end)
  return TweenService:GetValue(a, okS and es or Enum.EasingStyle.Quad, okD and ed or Enum.EasingDirection.InOut)
end
local function C(x, y, z, rx, ry, rz) return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0)) end
-- the sim's poseAt / rigCFs, ported 1:1 (effect space; the caller applies the origin)
local function poseAtRaw(t, rig)
  local K = rig.keys
  local i = 1
  while i < #K and K[i + 1].t <= t do i += 1 end
  local a, b = K[i], K[math.min(#K, i + 1)]
  local f = 0
  if b ~= a and b.t > a.t then f = easeV(b.style, b.dir, (t - a.t) / (b.t - a.t)) end
  local pose = {stretch = {}}
  for _, j in JOINTS do
    local p, q = a.pose[j] or {0, 0, 0}, b.pose[j] or {0, 0, 0}
    pose[j] = {p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f, p[3] + (q[3] - p[3]) * f}
    local function sv(s) local v = (s or {})[j]; if type(v) == "table" then return v[1] or 1, v[2] or 1 end; return v or 1, 1 end
    local pk, pw = sv(a.stretch)
    local qk, qw = sv(b.stretch)
    pose.stretch[j] = {pk + (qk - pk) * f, pw + (qw - pw) * f}
  end
  local ra, rb = a.root, b.root
  pose.root = {}
  for k = 1, 5 do pose.root[k] = (ra[k] or 0) + ((rb[k] or 0) - (ra[k] or 0)) * f end
  pose.reach = {}
  for _, j in {"RightArm", "LeftArm"} do
    local p, q = (a.reach or {})[j] or {0, 0.6}, (b.reach or {})[j] or {0, 0.6}
    pose.reach[j] = {p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f}
  end
  pose.move = {}
  for _, j in JOINTS do
    local p, q = (a.move or {})[j], (b.move or {})[j]
    if p or q then p, q = p or {0, 0, 0}, q or {0, 0, 0}; pose.move[j] = {p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f, p[3] + (q[3] - p[3]) * f} end
  end
  local sa, sb = a.scale or 1, b.scale or 1
  pose.scale = sa + (sb - sa) * f
  local fa, fb = a.fade or 0, b.fade or 0
  pose.fade = fa + (fb - fa) * f
  return pose
end
function M.poseAt(t, rig)
  rig = rig or M.RIG
  local pose = poseAtRaw(t, rig)
  for j, d in rig.lag or {} do pose[j] = poseAtRaw(math.max(0, t - d), rig)[j] end   -- overlapping action
  return pose
end
function M.rigCFs(pose, rig)
  rig = rig or M.RIG
  local at, r, k = rig.at, pose.root, pose.stretch or {}
  local S = (rig.scale or 1) * (pose.scale or 1)   -- rig-local offsets scale with the body (the sim's rigCFs)
  local mv = pose.move or {}
  local base = C(at[1], at[2], at[3], 0, rig.facing, 0)
  local torso = base * C(r[1], 3 * S + r[2], r[3], r[5], r[4], 0) * C(0, 0, 0, pose.Torso[1], pose.Torso[2], pose.Torso[3])
  local function chain(px, py, pz, rot, ox, oy, oz, j) local m = j and mv[j] or {0, 0, 0}; return torso * CFrame.new(m[1], m[2], m[3]) * CFrame.new(px * S, py * S, pz * S) * C(0, 0, 0, rot[1], rot[2], rot[3]) * CFrame.new(ox * S, oy * S, oz * S) end
  local function kw(j) local v = k[j]; if type(v) == "table" then return v[1], v[2] end; return v or 1, 1 end
  local rch = pose.reach or {}
  local dR, dL = (rch.RightArm or {0})[1], (rch.LeftArm or {0})[1]
  local kRA, wRA = kw("RightArm")
  local kLA, wLA = kw("LeftArm")
  local kRL, wRL = kw("RightLeg")
  local kLL, wLL = kw("LeftLeg")
  local out = {Torso = torso, Head = chain(0, 1, 0, pose.Head, 0, 0.5, 0, "Head"), RightArm = chain(1, 0.5, 0, pose.RightArm, 0.5 * wRA, 0.5 - kRA - dR, 0, "RightArm"),
    LeftArm = chain(-1, 0.5, 0, pose.LeftArm, -0.5 * wLA, 0.5 - kLA - dL, 0, "LeftArm"), RightLeg = chain(1, -1, 0, pose.RightLeg, -0.5 * wRL, -kRL, 0, "RightLeg"), LeftLeg = chain(-1, -1, 0, pose.LeftLeg, 0.5 * wLL, -kLL, 0, "LeftLeg")}
  out.RightHand = out.RightArm * CFrame.new(0, (-kRA - 0.15) * S, 0)
  out.LeftHand = out.LeftArm * CFrame.new(0, (-kLA - 0.15) * S, 0)
  out.RightFoot = out.RightLeg * CFrame.new(0, (-kRL + 0.2) * S, -0.2 * S)
  out.LeftFoot = out.LeftLeg * CFrame.new(0, (-kLL + 0.2) * S, -0.2 * S)
  out.Chest = torso * CFrame.new(0, 0.2 * S, -0.7 * S)
  out.Root = base * C(r[1], r[2], r[3], 0, r[4], 0)
  return out
end
-- One R6 model driven by one key track: HumanoidRootPart anchored and placed every frame, each
-- Motor6D.Transform = the sim's joint rotation conjugated into the joint's frame
-- (Transform = Rc0^-1 * R * Rc0), and stretched limbs resized with the joint end held (C1 shifted
-- by (k - 1) * half the limb's length), so the pose matches the sim exactly.
local function driver(character, game)
  local hrp = character:FindFirstChild("HumanoidRootPart")
  local torso = character:FindFirstChild("Torso")
  if not (hrp and torso) then return nil end
  local animate = character:FindFirstChild("Animate")
  if animate then animate.Disabled = true end
  local hum = character:FindFirstChildOfClass("Humanoid")
  local animator = hum and hum:FindFirstChildOfClass("Animator")
  if animator then for _, tr in animator:GetPlayingAnimationTracks() do tr:Stop(0) end end
  local motors = {Torso = hrp:FindFirstChild("RootJoint"), Head = torso:FindFirstChild("Neck"), RightArm = torso:FindFirstChild("Right Shoulder"),
    LeftArm = torso:FindFirstChild("Left Shoulder"), RightLeg = torso:FindFirstChild("Right Hip"), LeftLeg = torso:FindFirstChild("Left Hip")}
  local rc0, c1, size = {}, {}, {}
  for j, m in motors do
    rc0[j] = m.C0 - m.C0.Position
    c1[j] = m.C1
    if m.Part1 then size[j] = m.Part1.Size end
  end
  if not game then hrp.Anchored = true end
  local tubes = {}
  for _, j in {"RightArm", "LeftArm"} do
    local arm = character:FindFirstChild(j == "RightArm" and "Right Arm" or "Left Arm")
    local tb = Instance.new("Part")
    tb.Name = j .. "Tube"
    tb.Shape = Enum.PartType.Cylinder
    tb.Anchored, tb.CanCollide, tb.CanQuery, tb.CanTouch, tb.CastShadow = true, false, false, false, true
    tb.Material = Enum.Material.SmoothPlastic
    tb.Color = arm and arm.Color or Color3.fromRGB(234, 184, 146)
    tb.Transparency = 1
    tb.Size = Vector3.new(1, 0.6, 0.6)
    tb.Parent = character
    tubes[j] = tb
  end
  local d = {character = character, hrp = hrp, motors = motors, tubes = tubes, scale = 1, fade = 0}
  -- fade: LocalTransparencyModifier on every part and decal (a stand fading in, a caster hidden until a fusion)
  local skin = {}
  for _, x in character:GetDescendants() do if x:IsA("BasePart") or x:IsA("Decal") then table.insert(skin, x) end end
  local function setFade(f)
    if math.abs(f - d.fade) < 0.003 then return end
    d.fade = f
    for _, x in skin do x.LocalTransparencyModifier = f end
  end
  -- scale: a key multiplier on the model as built (Model:ScaleTo scales parts AND joints); the cached joint
  -- frames and limb sizes are re-read after each rescale so the stretch code does not undo it
  local function setScale(s)
    if math.abs(s - d.scale) < 0.004 then return end
    d.scale = s
    local ok, err = pcall(function() character:ScaleTo(s) end)
    if not ok and not M.PROP_FAILS.ScaleTo then M.PROP_FAILS.ScaleTo = true; warn("[" .. M.NAME .. "] ScaleTo failed on " .. character.Name .. ": " .. tostring(err)) end
    if ok and not d.scaleLogged and math.abs(s - 1) > 0.3 then d.scaleLogged = true; local t = character:FindFirstChild("Torso"); print("[" .. M.NAME .. "] " .. character.Name .. " scale " .. string.format("%.2f", character:GetScale()) .. " torso " .. tostring(t and t.Size)) end
    for j, m in motors do rc0[j] = m.C0 - m.C0.Position; c1[j] = m.C1; if m.Part1 then size[j] = m.Part1.Size end end
  end
  function d.apply(origin, rig, pose)
    local r = pose.root
    setScale(pose.scale or 1)
    setFade(pose.fade or 0)
    local S = (rig.scale or 1) * (pose.scale or 1)
    -- game mode: the root belongs to the game's physics (replicated, owned by the player), so the root keys move
    -- the body through the RootJoint instead: same pose on screen, no fight with replication
    local D
    if game then
      -- the visual offset is where the move's path puts the root (as the showcase would place it) relative to
      -- where the root REALLY is: a client-side lunge that moved the root along the path leaves ~nothing to
      -- add (no double count, no snap back at the end), a remote player's lagging root is made up for
      D = hrp.CFrame:Inverse() * (origin * C(rig.at[1], rig.at[2], rig.at[3], 0, rig.facing, 0) * C(r[1], 3 * S + r[2], r[3], r[5], r[4], 0))
    else
      hrp.CFrame = origin * C(rig.at[1], rig.at[2], rig.at[3], 0, rig.facing, 0) * C(r[1], 3 * S + r[2], r[3], r[5], r[4], 0)
    end
    local mv = pose.move or {}
    for j, m in motors do
      local rot = pose[j]
      local o = mv[j]
      -- a joint offset (torso frame) slides the limb off its joint: Transform = Rc0^-1 * T(o) * R * Rc0
      m.Transform = rc0[j]:Inverse() * (o and CFrame.new(o[1], o[2], o[3]) or CFrame.new()) * C(0, 0, 0, rot[1], rot[2], rot[3]) * rc0[j]
      if D and j == "Torso" then m.Transform = m.C0:Inverse() * D * m.C0 * m.Transform end
    end
    for _, j in LIMBS do
      local m, s = motors[j], pose.stretch[j]
      local k, w = 1, 1
      if type(s) == "table" then k, w = s[1], s[2] elseif s then k = s end
      local rr = pose.reach and pose.reach[j]
      local rd = rr and rr[1] or 0
      if m and m.Part1 and size[j] then
        local want = Vector3.new(size[j].X * w, size[j].Y * k, size[j].Z * w)
        if (m.Part1.Size - want).Magnitude > 1e-3 then m.Part1.Size = want end
        -- hold the joint end: shift C1 by (k - 1) * half the length, and sideways by (w - 1) * half
        -- the width toward the joint's side, so a thicker limb grows outward, not into the torso;
        -- a rubber reach slides the whole limb a further rd studs out along its own line
        local jx = c1[j].Position.X
        local sx = jx > 0 and 1 or (jx < 0 and -1 or 0)
        m.C1 = CFrame.new(sx * (w - 1) * size[j].X / 2, (k - 1) * size[j].Y / 2 + rd, 0) * c1[j]
        local tb = tubes[j]
        if tb then
          if rd > 0.35 then
            -- the tube runs from inside the shoulder to 0.15 inside the slid-out limb's top, in the
            -- limb's own frame: limb top = Part1.CFrame * (0, Y*k/2, 0); shoulder end rd further up
            local top = m.Part1.CFrame * CFrame.new(0, size[j].Y * k / 2 - 0.15, 0)
            local len = rd                                  -- 0.15 inside the limb up to 0.35 above the shoulder pivot (= the sim)
            tb.Size = Vector3.new(len, rr[2], rr[2])
            tb.CFrame = top * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
            tb.Transparency = 0
          elseif tb.Transparency < 1 then
            tb.Transparency = 1
          end
        end
      end
    end
  end
  function d.release()
    setFade(0)
    if d.scale ~= 1 then setScale(1) end
    for j, m in motors do
      m.Transform = CFrame.new()
      if size[j] and m.Part1 then m.Part1.Size = size[j]; m.C1 = c1[j] end
    end
    for _, tb in tubes do tb:Destroy() end
    if animate then animate.Disabled = false end
  end
  return d
end
-- Drive the caster (M.RIG) and every actor (M.ACTORS: runtime copies of the caster, e.g. shadow
-- clones, shown only inside their show window) for the move's duration; parts with Follow ride
-- the rig they name ("RightHand" = caster, "Clone1.RightHand" = actor Clone1).
function M.animate(h, character)
  if not M.RIG or not character then return end
  local main = driver(character, h.game)
  if not main then warn("[" .. M.NAME .. "] caster is not an R6 rig") return end
  h.actorModels = {}
  local actors = {}
  if #M.ACTORS > 0 then
    local was = character.Archivable
    character.Archivable = true
    local folder = Instance.new("Folder")
    folder.Name = M.NAME .. "_Actors"
    h.actorFolder = folder
    local cast = game:GetService("ReplicatedStorage"):FindFirstChild("Showcase")
    cast = cast and cast:FindFirstChild("Cast")
    for _, a in M.ACTORS do
      -- an actor copies the caster, another rig ("model" = a Showcase.Cast name: The World, Vegeta) or the target ("@target")
      local src = character
      if a.rig.model == "@target" then src = h.target elseif a.rig.model then src = cast and cast:FindFirstChild(a.rig.model) end
      if not src then warn("[" .. M.NAME .. "] no model for actor " .. a.name .. " (" .. tostring(a.rig.model) .. ")"); continue end
      local wasA = src.Archivable
      src.Archivable = true
      local c = src:Clone()
      src.Archivable = wasA
      for _, x in c:GetDescendants() do if x:IsA("BillboardGui") or x:IsA("Highlight") then x:Destroy() end end
      c.Name = a.name
      for _, x in c:GetDescendants() do if x:IsA("BaseScript") then x:Destroy() end end
      local hum = c:FindFirstChildOfClass("Humanoid")
      if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
      local d = driver(c)
      if d then table.insert(actors, {spec = a, model = c, d = d, shown = false}) h.actorModels[a.name] = c end
    end
    character.Archivable = was
    folder.Parent = workspace
  end
  local t0 = os.clock()
  local hold = M.DURATION + 0.6
  local conn
  -- game mode drives the joints on Stepped: on a live character the Animator rewrites Motor6D.Transform after
  -- RenderStepped, so poses written there never showed (2026-10-30, Awakened Arena: the effects played, the body
  -- stood idle). Stepped runs after the animation step, so these poses win. The showcase (anchored dummies)
  -- keeps RenderStepped, unchanged.
  conn = (h.game and RunService.Stepped or RunService.RenderStepped):Connect(function()
    local t = os.clock() - t0
    if t > hold or not character.Parent then
      conn:Disconnect()
      main.release()
      if h.actorFolder then h.actorFolder:Destroy() end
      if h.targetHidden then M.hideTarget(h, false) end
      return
    end
    local sets = {}
    local pose = M.poseAt(t, M.RIG)
    main.apply(h.origin, M.RIG, pose)
    sets[""] = M.rigCFs(pose, M.RIG)
    for _, A in actors do
      local on = t >= A.spec.show[1] and t < A.spec.show[2]
      if on then
        local p = M.poseAt(t, A.spec.rig)
        A.d.apply(h.origin, A.spec.rig, p)
        sets[A.spec.name] = M.rigCFs(p, A.spec.rig)
        if not A.shown then A.shown = true; A.model.Parent = h.actorFolder end
      elseif A.shown then
        A.shown = false
        A.model.Parent = nil
      end
    end
    for _, f in M.FOLLOW do
      local part = h.byPath[f[1]]
      local who, pn = string.match(f[2], "^(.-)%.(.+)$")
      local cfs = sets[who or ""]
      local cf = cfs and cfs[pn or f[2]]
      if part and cf then part.CFrame = h.origin * cf * f[3] end
    end
  end)
end
-- the real target hidden while a copy of it ("@target" actor) acts (cut apart, frozen, shattered); the
-- health bar (a BillboardGui) stays up so the damage still reads
function M.hideTarget(h, on)
  local tg = h.target
  if not tg then return end
  h.targetHidden = on
  for _, x in tg:GetDescendants() do if x:IsA("BasePart") or x:IsA("Decal") then x.LocalTransparencyModifier = on and 1 or 0 end end
end
-- afterimage: an anchored copy of the caster's (or an actor's) visible body at this instant, fading out
function M.ghost(h, life, color, tr0, actor, parts, keep)
  local character = actor and h.actorModels and h.actorModels[actor] or h.caster
  if not character then return end
  local only
  if parts then
    -- sim joint names -> R6 part names ("RightArm" is "Right Arm" on a real rig; v1 matched nothing,
    -- so the Gatling's arm afterimages never appeared), plus that limb's rubber tube
    local R6 = {RightArm = "Right Arm", LeftArm = "Left Arm", RightLeg = "Right Leg", LeftLeg = "Left Leg"}
    only = {}
    for _, p in parts do only[p] = true; if R6[p] then only[R6[p]] = true end; only[p .. "Tube"] = true end
  end
  local folder = Instance.new("Folder")
  folder.Name = "Ghost"
  for _, d in character:GetDescendants() do
    if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" and (not only or only[d.Name] or (d.Parent:IsA("Accessory") and false)) then
      local g = d:Clone()
      for _, c in g:GetChildren() do if not (c:IsA("SpecialMesh") or (keep and (c:IsA("Decal") or c:IsA("SurfaceAppearance")))) then c:Destroy() end end
      g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
      g.CFrame = d.CFrame
      if not keep then
        g.Color = color
        g.Material = Enum.Material.Neon
        if g:IsA("MeshPart") then g.TextureID = "" end
      end
      g.Transparency = tr0
      g.Parent = folder
      TweenService:Create(g, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
    end
  end
  folder.Parent = workspace
  task.delay(life + 0.1, function() folder:Destroy() end)
end

M.STAGE = {night = false}
function M.applyStage(h)
  local keep = {ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor}
  h.restoreStage = function() for k, v in keep do Lighting[k] = v end end
  if M.STAGE.night then Lighting.ClockTime = 0; Lighting.Brightness = 0.6; Lighting.Ambient = Color3.new(0.05, 0.06, 0.1); Lighting.OutdoorAmbient = Color3.new(0.12, 0.14, 0.22) end
  if M.STAGE.fogEnd then Lighting.FogStart = M.STAGE.fogStart; Lighting.FogEnd = M.STAGE.fogEnd; Lighting.FogColor = M.STAGE.fogColor end
end

local function find(h, path) return h.byPath[path] end

-- camera effects (shake + FOV punch) through one driver: each frame it takes back the offset it
-- added last frame (unless something else moved the camera since, e.g. a tween or a cut), then adds this frame's
local CamFX = {sh = {}, fv = {}}
local function camStep()
  local cam = workspace.CurrentCamera
  local now = os.clock()
  local cf, fov = cam.CFrame, cam.FieldOfView
  local base = (CamFX.lastCF and cf == CamFX.lastCF) and cf * CamFX.lastOff:Inverse() or cf
  local bfov = (CamFX.lastFov and math.abs(fov - CamFX.lastFov) < 1e-4) and fov - CamFX.lastD or fov
  local ox, oy, oz, d = 0, 0, 0, 0
  for i = #CamFX.sh, 1, -1 do
    local s = CamFX.sh[i]; local a = (now - s.t0) / s.time
    if a > 1 then table.remove(CamFX.sh, i) else
      local k = s.amp * (1 - a) ^ 2; local ph = (now - s.t0) * s.freq
      ox += math.sin(ph * 6.1) * k; oy += math.sin(ph * 7.3 + 1) * k; oz += math.sin(ph * 5.7 + 2) * k * 0.5
    end
  end
  for i = #CamFX.fv, 1, -1 do
    local f = CamFX.fv[i]; local a = now - f.t0
    if a > f.i + f.o then table.remove(CamFX.fv, i)
    elseif a < f.i then d += f.by * TweenService:GetValue(a / f.i, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    else d += f.by * (1 - TweenService:GetValue((a - f.i) / f.o, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)) end
  end
  local off = CFrame.new(ox, oy, oz)
  cam.CFrame = base * off
  cam.FieldOfView = math.clamp(bfov + d, 1, 120)
  CamFX.lastCF, CamFX.lastOff, CamFX.lastFov, CamFX.lastD = cam.CFrame, off, cam.FieldOfView, d
  if #CamFX.sh == 0 and #CamFX.fv == 0 then
    RunService:UnbindFromRenderStep("RVFX_CamFX"); CamFX.on = false; CamFX.lastCF = nil; CamFX.lastFov = nil
  end
end
local function camfx(kind, e)
  e.t0 = os.clock()
  table.insert(kind == "shake" and CamFX.sh or CamFX.fv, e)
  if not CamFX.on then CamFX.on = true; RunService:BindToRenderStep("RVFX_CamFX", Enum.RenderPriority.Camera.Value + 2, camStep) end
end
-- screen overlays in the player's PlayerGui: "lines" = an image re-rolled at 30 Hz (focus/speed lines), "bars" = letterbox
local function overlay(h, o)
  local plr = game:GetService("Players").LocalPlayer
  local pg = plr and plr:FindFirstChildOfClass("PlayerGui"); if not pg then return end
  local g = Instance.new("ScreenGui"); g.Name = "RVFX_" .. o.kind; g.IgnoreGuiInset = true; g.ResetOnSpawn = false; g.DisplayOrder = o.order or 40
  g.Parent = pg
  task.delay(o.time + 0.05, function() g:Destroy() end)
  if o.kind == "bars" then
    for _, top in {true, false} do
      local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = o.color; f.BackgroundTransparency = o.tr
      f.AnchorPoint = Vector2.new(0, top and 0 or 1); f.Position = UDim2.fromScale(0, top and 0 or 1); f.Size = UDim2.fromScale(1, 0); f.Parent = g
      TweenService:Create(f, TweenInfo.new(o.fin, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, o.size)}):Play()
      task.delay(math.max(0, o.time - o.fout), function() TweenService:Create(f, TweenInfo.new(o.fout, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.fromScale(1, 0)}):Play() end)
    end
    return
  end
  local uri = h.folder and h.folder:GetAttribute("Overlay_" .. (o.image:gsub("[^%w_]", "_")))
  if not uri or uri == "" then warn("[RVFX] overlay image missing " .. o.image); return end
  local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Image = uri; im.ImageColor3 = o.color
  im.AnchorPoint = Vector2.new(0.5, 0.5); im.Position = UDim2.fromScale(0.5, 0.5); im.Parent = g
  local t0, fr = os.clock(), -1
  local rng = Random.new(o.seed or 1)
  local c; c = RunService.RenderStepped:Connect(function()
    local a = os.clock() - t0
    if a > o.time or not g.Parent then c:Disconnect() return end
    local vp = workspace.CurrentCamera.ViewportSize
    local D = math.sqrt(vp.X * vp.X + vp.Y * vp.Y) * (o.scale or 1.08)
    local k = math.floor(a * 30)
    if k ~= fr then fr = k; im.Rotation = o.spin and rng:NextNumber(0, 360) or (o.rot or 0); local s = 1 + rng:NextNumber(-0.04, 0.04); im.Size = UDim2.fromOffset(D * s, D * s) end
    local fade = math.min(1, a / math.max(o.fin, 1e-3), (o.time - a) / math.max(o.fout, 1e-3))
    im.ImageTransparency = 1 - (1 - o.tr) * math.clamp(fade, 0, 1)
  end)
end

function M.play(h)
  if h.caster then M.animate(h, h.caster) end
  for _, d in h.folder:GetDescendants() do if d:IsA("Highlight") and d:GetAttribute("AdorneeCaster") then d.Adornee = h.caster end; if d:IsA("Highlight") and d:GetAttribute("AdorneeTarget") then d.Adornee = h.target end; if d:IsA("Highlight") and d:GetAttribute("AdorneeActor") and h.actorModels then d.Adornee = h.actorModels[d:GetAttribute("AdorneeActor")] end end
  if h.screen ~= false then local cam = workspace.CurrentCamera; cam.CameraType = Enum.CameraType.Scriptable; cam.CFrame = (h.origin or CFrame.new()) * CFrame.lookAt(Vector3.new(5, 5, 11), Vector3.new(0.8, 3, 0)); cam.FieldOfView = 70 end
  task.delay(2.00 + 1, function() h.folder:Destroy(); for _, d in h.lighting do d:Destroy() end; if h.restoreStage then h.restoreStage() end end)
end
return M