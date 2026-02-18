--!strict
--!optimize 2

local crunchyroll = require("./roblox_packages/crunchyroll-fork")

type registryvalue = {
	motors: {[string]: Motor6D},
	animations: {[crunchyroll.AnimationAsset]: AnimationTrackData & interalTrackData},
	character: Model
}

type TrackData = {
    looped: boolean?,
    fadein: number?,
    fadeout: number?,
    fadecurve: {
        fadein: ((alpha: number) -> number)?,
        fadeout: ((alpha: number) -> number)?,
        shared: ((alpha: number) -> number)?,
    }?
}

export type crunchwrapTrackData = {
	-- 0-1
	alpha: number,

	weight: number,

	-- arbitrary number
	priority: number,
} & TrackData

export type AnimationTrackData = {
	-- 0-1
	alpha: number,

	-- 0-1
	startFadeTime: number,
	stopFadeTime: number,
	weight: number,

	-- arbitrary number
	priority: number,
} & TrackData

type interalTrackData = {
    fadein_Elapsed: number?,
    fadeout_Elapsed: number?,
    originalWeight: number
}

local rig_registry: {[crunchyroll.Rig]: registryvalue} = {}

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
	local collect = {} :: {[string]: Motor6D}

	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") then continue end
        if motor.Part1 == nil then continue end
		
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
		character = character
	}
end

--[==[
Adds a animation if it is not added yet. If not looped then it will automatically remove it!

@param animation The animation to use
@param rig The crunchyroll rig
@param trackdata Track data to use
]==]
local function add_animation(animation: crunchyroll.AnimationAsset, rig: crunchyroll.Rig, trackdata: crunchwrapTrackData)
	local data = retrieve(rig)

	if data == nil then return end

    local transform = table.clone(trackdata) :: AnimationTrackData & interalTrackData

    transform.startFadeTime = 0
    transform.stopFadeTime = 0

    if transform.fadein then
        transform.fadein_Elapsed = 0
    end

    if transform.fadeout then
        transform.fadeout_Elapsed = 0
    end

    transform.originalWeight = transform.weight

	if data.animations[animation] == nil then
		data.animations[animation] = transform
	end
end

--[==[
Removes an animation

@param animation The animation to remove
@param rig The crunchyroll rig
]==]
local function remove_animation(animation: crunchyroll.AnimationAsset, rig: crunchyroll.Rig)
	local data = retrieve(rig)

	if data == nil then return end

	data.animations[animation] = nil
end

local function exponential_lerp(t: number, k: number): number
	if k == 0 then -- Math limits workaround
		return t -- return to linear
	end

	local curve = 1 - math.exp(-k * t)
	local max = 1 - math.exp(-k)

	curve = curve / max

	return curve
end

local function getCurve(track: AnimationTrackData & interalTrackData, type: "in" | "out",  expo: number)
    local curve = function(alpha: number)
        return exponential_lerp(alpha, expo)
    end

    if track.fadecurve ~= nil then
        if track.fadecurve["fade"..type] ~= nil then
            curve = track.fadecurve["fade"..type]
        elseif track.fadecurve.shared ~= nil then
            curve = track.fadecurve.shared
        end
    end

    return curve
end

--[==[
Solves all animations in all rigs, and updates the corresponding Motor6Ds in each rig

@param dT The time step to animate
]==]
local function step(dT: number)
	for rig, data in rig_registry do
		for asset, track in data.animations do
			track.alpha += dT / asset.length
            
            if track.looped then
                track.alpha %= 1
            else
                if track.alpha >= 1 then
                    -- Remove if not looped!
                    remove_animation(asset, rig)
                end
            end

            -- Step fades

            local weight = 0
            local average = 0

            if track.fadein_Elapsed and track.fadein then
                weight += getCurve(track, "in", -1)(track.fadein_Elapsed / track.fadein) * track.originalWeight
                average += 1
                track.fadein_Elapsed += dT

                if track.fadein_Elapsed >= track.fadein then
                    track.fadein_Elapsed = nil
				    track.fadein = nil
                end
            end

            if track.fadeout_Elapsed and track.fadeout then
                local remainingAlpha = 1 - track.alpha
                local fadeAlpha = track.fadeout / asset.length
            
                -- Wait until there is enough time left to fade

                if fadeAlpha >= remainingAlpha then
                    weight += getCurve(track, "out", 1)(track.fadeout_Elapsed / track.fadeout)  * (-track.originalWeight) + track.originalWeight
                    average += 1

                    track.fadeout_Elapsed += dT

                    if track.fadeout_Elapsed >= track.fadeout then --Stop
                        track.fadeout = nil
                        track.fadeout_Elapsed = nil

                        remove_animation(asset, rig)
                    end
                end
            end

            if average > 0 then
                track.weight = weight/average
            end
		end

		crunchyroll.solve_animation(rig, data.animations, CFrame.identity, true)

        for index, limb in rig.limbs do
            local limbTransform = rig.limbTransforms[index]

			local position = limbTransform.position
			local quat_vector = limbTransform.quatVector
			local quat_scalar = limbTransform.quatScalar
			
			local transform = CFrame.new(
				position.x, position.y, position.z,
				quat_vector.x, quat_vector.y, quat_vector.z, quat_scalar
			)

            data.motors[limb.name].Transform = transform
        end
	end
end

return {
	register = register,
	add_animation = add_animation,
    remove_animation = remove_animation,
	step = step
}