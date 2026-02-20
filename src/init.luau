--!strict
--!optimize 2

local crunchyroll = require(script.Parent:FindFirstChild("crunchyroll"))

export type CrunchwrapAnimationTrack = AnimationTrackData & interalTrackData

type registryvalue = {
	motors: { [string]: Motor6D },
	animations: { [crunchyroll.AnimationAsset]: CrunchwrapAnimationTrack },
	character: Model,
}

type TrackData = {
	looped: boolean?,
	force_duration: number?,
	speed: number?,
	pause: boolean?,

	-- 0 to 1
	fadein: number?,
	fadeout: number?,

	fadecurve: {
		fadein: ((alpha: number) -> number)?,
		fadeout: ((alpha: number) -> number)?,
		shared: ((alpha: number) -> number)?,
	}?,
}

export type CrunchwrapTrackData = {
	alpha: number,
	weight: number,
	priority: number,
} & TrackData

export type AnimationTrackData = {
	alpha: number,
	start_fade_time: number,
	stop_fade_time: number,
	weight: number,
	priority: number,
} & TrackData

type interalTrackData = {
	fadein_Elapsed: number?,
	fadeout_Elapsed: number?,
	originalWeight: number,
	ended: boolean?,
}

local rig_registry: { [crunchyroll.Rig]: registryvalue } = {}

local function retrieve(rig: crunchyroll.Rig): registryvalue?
	if rig_registry[rig] == nil then
		warn("Rig is not registered!")
		return nil
	end

	return rig_registry[rig]
end

--[==[
Register the crunchyroll rig along with the player model
The limb names in the rig must match the character model's limbs correctly!

@param character The character to use
@param rig The crunchyroll rig which is accurate to the character
]==]
local function register(character: Model, rig: crunchyroll.Rig)
	local collect = {} :: { [string]: Motor6D }

	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") then
			continue
		end
		if motor.Part1 == nil then
			continue
		end

		for _, limb in rig.limbs do
			-- Checks motor to see Part1 for the associated limb
			if motor.Part1.Name == limb.name then
				-- If the motor is indeed controlling the limb, we assign
				collect[limb.name] = motor
			end
		end
	end

	rig_registry[rig] = {
		motors = collect,
		animations = {},
		character = character,
	}
end

--[==[
Adds a animation if it is not added yet. If not looped then it will automatically remove it!

Info: Fade in/out is not in seconds but in alpha (0 to 1)

@param animation The animation to use
@param rig The crunchyroll rig
@param trackdata Track data to use
]==]
local function add_animation(
	animation: crunchyroll.AnimationAsset,
	rig: crunchyroll.Rig,
	trackdata: CrunchwrapTrackData
)
	local data = retrieve(rig)

	if data == nil then
		return
	end

	local transform = table.clone(trackdata) :: CrunchwrapAnimationTrack

	transform.start_fade_time = 0
	transform.stop_fade_time = 0

	if transform.fadein then
		transform.fadein_Elapsed = 0
	end

	if transform.fadeout then
		transform.fadeout_Elapsed = 0
	end

	transform.originalWeight = transform.weight

	-- Remove fade if set to zero :sob:
	if transform.fadein == 0 then
		transform.fadein = nil
		transform.fadein_Elapsed = nil
	end

	-- If looped then why bother adding a fade out?
	if transform.fadeout == 0 or transform.looped then
		transform.fadeout = nil
		transform.fadeout_Elapsed = nil
	end

	if data.animations[animation] == nil then
		data.animations[animation] = transform
	end
end

--[==[
Removes an animation with fadeout time (overrides)
Track.looped is set to false

What happens is that it will fade out

Info: Fadeout is not in seconds but in alpha (0 to 1)

@param animation The animation to remove
@param rig The crunchyroll rig
]==]
local function remove_animation(
	animation: crunchyroll.AnimationAsset,
	rig: crunchyroll.Rig,
	fadedata: {
		fadetime: number,
		fadecurve: ((alpha: number) -> number)?,
	}
)
	local data = retrieve(rig)
	if data == nil then
		return
	end

	local track = data.animations[animation]
	assert(track, "Track does not exist!")

	local fadeAlpha = fadedata.fadetime
	local remainingAlpha = 1 - track.alpha

	if remainingAlpha >= fadeAlpha then
		-- We have enough time
		track.fadeout = fadedata.fadetime
	else
		-- Use remaining time left
		track.fadeout = remainingAlpha
	end

	track.ended = true
	track.fadeout_Elapsed = 0
	track.looped = false
end

--[==[
Force remove an animation without fadeout

@param animation The animation to remove
@param rig The crunchyroll rig
]==]
local function force_remove_animation(animation: crunchyroll.AnimationAsset, rig: crunchyroll.Rig)
	local data = retrieve(rig)

	if data == nil then
		return
	end

	data.animations[animation] = nil
end

local function exponential_lerp(t: number, k: number): number
	if k == 0 then -- undefined?
		return t -- return to linear
	end

	local curve = 1 - math.exp(-k * t)
	local max = 1 - math.exp(-k)

	curve = curve / max

	return curve
end

local function getCurve(track: CrunchwrapAnimationTrack, type: "in" | "out", expo: number)
	local curve = function(alpha: number)
		return exponential_lerp(alpha, expo)
	end

	if track.fadecurve ~= nil then
		if track.fadecurve["fade" .. type] ~= nil then
			curve = track.fadecurve["fade" .. type]
		elseif track.fadecurve.shared ~= nil then
			curve = track.fadecurve.shared
		end
	end

	return curve
end

local function solve_track(
	dT: number,
	rig: crunchyroll.Rig,
	asset: crunchyroll.AnimationAsset,
	track: CrunchwrapAnimationTrack
)
	local divider = asset.length

	if track.force_duration then
		divider = track.force_duration
	end

	if track.speed and track.speed ~= 0 then
		divider /= track.speed
	elseif track.speed == 0 then
		track.pause = true
	end

	-- Hard check again, because we dont like zeros
	if track.fadein == 0 then
		track.fadein = nil
		track.fadein_Elapsed = nil
	end

	if track.fadeout == 0 then
		track.fadeout = nil
		track.fadeout_Elapsed = nil
	end

	track.alpha += dT / divider

	if track.looped then
		track.alpha %= 1
	else
		-- Check for cases to remove
		-- If alpha is less than zero (also negative speed)
		if track.speed then
			if track.alpha <= 0 then
				force_remove_animation(asset, rig)
				return
			end
		end

		-- Finished animation so remove
		if track.alpha >= 1 then
			-- Remove if not looped!
			force_remove_animation(asset, rig)
			return
		end
	end

	-- Step fades

	local fadeinFactor = 1
	local fadeoutFactor = 1

	-- If fadein is specified
	if track.fadein_Elapsed and track.fadein then
		-- Apply curves to weight
		fadeinFactor = getCurve(track, "in", -1)(track.fadein_Elapsed / track.fadein)
		track.fadein_Elapsed += dT / math.abs(divider)

		-- Stop if elapsed finishes
		if track.fadein_Elapsed >= track.fadein then
			track.fadein_Elapsed = nil
			track.fadein = nil
		end
	end

	-- If fadeout
	if track.fadeout_Elapsed and track.fadeout and track.ended ~= true then
		local remainingAlpha = 1 - track.alpha

		if track.speed then
			if track.speed < 0 then
				remainingAlpha = track.alpha
			end
		end

		local fadeAlpha = track.fadeout -- as it is not in seconds

		-- Wait until there is enough time left to fade

		if fadeAlpha >= remainingAlpha then
			fadeoutFactor = 1 - getCurve(track, "out", 1)(track.fadeout_Elapsed / track.fadeout)

			track.fadeout_Elapsed += dT / math.abs(divider)

			-- Now stop it after finishing
			if track.fadeout_Elapsed >= track.fadeout then --Stop
				track.fadeout = nil
				track.fadeout_Elapsed = nil

				force_remove_animation(asset, rig)
			end
		end
	elseif track.ended and track.fadeout and track.fadeout_Elapsed then
		fadeoutFactor = 1 - getCurve(track, "out", 1)(track.fadeout_Elapsed / track.fadeout)

		track.fadeout_Elapsed += dT / math.abs(divider)

		if track.fadeout_Elapsed >= track.fadeout then
			force_remove_animation(asset, rig)
		end
	end

	track.weight = track.originalWeight * fadeinFactor * fadeoutFactor
end

local function update_motors(data: registryvalue, rig: crunchyroll.Rig)
	for index, limb in rig.limbs do
		local limbTransform = rig.limb_transforms[index]

		local position = limbTransform.position
		local quat_vector = limbTransform.quat_vector
		local quat_scalar = limbTransform.quat_scalar

		local transform = CFrame.new(
			position.x,
			position.y,
			position.z,
			quat_vector.x,
			quat_vector.y,
			quat_vector.z,
			quat_scalar
		)

		data.motors[limb.name].Transform = transform
	end
end

local function solve_rig(dT: number, rig: crunchyroll.Rig, data: registryvalue)
	for asset, track in data.animations do
		if track.pause then
			continue
		end
		if track.speed == 0 then
			continue
		end

		solve_track(dT, rig, asset, track)
	end

	crunchyroll.solve_animation(rig, data.animations, CFrame.identity)

	update_motors(data, rig)
end

--[==[
Solves all animations in rigs, and updates the corresponding Motor6Ds in each rig

@param dT The time step to animate
@param rigs Leave blank to update all rigs, else pass a table of the rigs to update
]==]
local function step(dT: number, rigs: { crunchyroll.Rig }?)
	if rigs == nil then
		for rig, data in rig_registry do
			solve_rig(dT, rig, data)
		end
	else
		for _, rig in rigs do
			local data = retrieve(rig)

			if not data then
				continue
			end
			solve_rig(dT, rig, data)
		end
	end
end

--[==[
Returns the full internal track stored for the animation. Table is mutable, so any changes to anything is reflected realtime

@param rig The rig
@param the animation
]==]
local function retrieve_track(
	rig: crunchyroll.Rig,
	animation: crunchyroll.AnimationAsset
): CrunchwrapAnimationTrack?
	return rig_registry[rig].animations[animation]
end

return {
	register = register,
	add_animation = add_animation,
	remove_animation = remove_animation,
	force_remove_animation = force_remove_animation,
	step = step,
	retrieve_track = retrieve_track,
	curve_preset = {
		exponential = exponential_lerp,
	},
}
