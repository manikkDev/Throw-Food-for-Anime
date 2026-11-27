--!strict
-- FoodHold - where a food sits in the hands, by its throw class (plan 13
-- phase C). One function, used by the throw spot (the food held while the
-- player aims) and by the throw's wind-up, so the food does not jump when the
-- throw starts.
--
--   pitch  on the upturned right hand, upright (a rice ball, an apple)
--   heave  between both hands, LEVEL (a bowl, a plate, a feast: the soup stays in)
--   spin   gripped at its edge by the right hand, flat like a frisbee (a pizza, a skewer)
--
-- The numbers are the ones the clips were authored to (assets/animations batch
-- r7, work/anim/upload7/README.md: HoldPitch / HoldHeave / HoldSpin and their
-- throws), with the stand-in prop's size replaced by the real food's.

local FoodHold = {}

-- the gap between the hand's end face and the food resting on it (the clips' 0.15)
local REST = 0.15
-- a level food's centre over the two hands' midpoint: its bottom sits this far above the hand
-- centres (HoldHeave: a 1.1-tall bowl centred 0.674 above the midpoint)
local HEAVE_GAP = 0.124

local function part(character: Model, name: string): BasePart?
	local found = character:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- the character's facing, flat (yaw only): a level food turns with the body, never tips
local function facing(character: Model): CFrame
	local root = part(character, "HumanoidRootPart")
	if not root then
		return CFrame.identity
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, flat)
end

--- The size of a food model as it is in the hand (its bounding box), for `cframe`.
function FoodHold.sizeOf(carrier: Instance): Vector3
	local model = carrier:FindFirstChildWhichIsA("Model")
	if model then
		local _, size = model:GetBoundingBox()
		return size
	end
	return Vector3.new(1.8, 1.8, 1.8)
end

--- The CFrame of the food's carrier for a character holding a `class` food of
--- `size` (studs), or nil when the rig has no hands (R6, mid-respawn).
function FoodHold.cframe(character: Model?, class: string, size: Vector3): CFrame?
	if not character then
		return nil
	end
	local right = part(character, "RightHand")
	if not right then
		return nil
	end
	if class == "heave" then
		local left = part(character, "LeftHand")
		if left then
			local mid = (left.Position + right.Position) / 2
			return facing(character) + (mid + Vector3.new(0, HEAVE_GAP + size.Y / 2, 0))
		end
	elseif class == "spin" then
		-- gripped at the rim: the centre is half its width beyond the hand's end face. Kept LEVEL
		-- by the world, not by the hand (seen in play: taking the food's up from the hand's own
		-- axes showed the pizza's underside at 40 degrees on a real avatar)
		local reach = REST + math.max(size.X, size.Z) / 2
		local at = (right.CFrame * CFrame.new(0, -reach, 0)).Position
		return facing(character) + at
	end
	-- resting on the upturned hand, kept upright: only its position follows the hand
	local at = (right.CFrame * CFrame.new(0, -(REST + size.Y / 2), 0)).Position
	return facing(character) + at
end

return FoodHold
