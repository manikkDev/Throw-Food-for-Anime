--!strict
-- Particles - the throw's placeholder effects, built in code from Roblox's
-- built-in particle textures. Section 4 replaces these with authored VFX:
-- keep every effect behind one of the small functions below so that swap is
-- three function bodies and nothing else.
--
-- Each one-shot cleans itself up; nothing here runs per frame.

local Debris = game:GetService("Debris")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local Particles = {}

local function anchor(position: Vector3, size: Vector3, seconds: number): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Position = position
	part.Parent = workspace
	Debris:AddItem(part, seconds)
	return part
end

--- A ring of dust flat on the ground where something lands. `scale` 1 is the
--- first bounce; smaller for the ones after it.
function Particles.dust(position: Vector3, scale: number)
	local part = anchor(position, Vector3.new(2.4, 0.2, 2.4) * scale, 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Color = ColorSequence.new(Color3.fromRGB(240, 232, 214))
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(9 * scale, 15 * scale)
	emitter.Drag = 5
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8 * scale),
		NumberSequenceKeypoint.new(1, 3 * scale),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(math.floor(22 * scale))
end

--- A steady, colourless sparkle on a part (the silhouette before the reveal:
--- it must not give the rarity away). Destroy the emitter to stop it.
function Particles.sparkles(part: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245))
	emitter.LightEmission = 0.7
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(1.5, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 16
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = part
	return emitter
end

--- A one-shot burst in `color` (the rarity colour at the reveal; a small one
--- when another player's catch lands).
function Particles.burst(position: Vector3, color: Color3, count: number)
	local part = anchor(position, Vector3.new(1, 1, 1), 2.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(14, 30)
	emitter.Drag = 3.5
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(count)
end

return Particles
