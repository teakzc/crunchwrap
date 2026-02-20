import { AnimationAsset, Rig } from "@rbxts/crunchyroll";

interface TrackData {
	looped?: boolean;
	force_duration?: number;
	speed?: number;
	pause?: boolean;

	// 0 to 1
	fadein?: number;
	fadeout?: number;

	fadecurve?: {
		fadein?: (alpha: number) => number;
		fadeout?: (alpha: number) => number;
		shared?: (alpha: number) => number;
	};
}

export interface AnimationTrackData extends TrackData {
	alpha: number;
	startFadeTime: number;
	stopFadeTime: number;
	weight: number;
	priority: number;
}

interface interalTrackData {
	fadein_Elapsed?: number;
	fadeout_Elapsed?: number;
	originalWeight: number;
	ended?: boolean;
}

export interface CrunchwrapTrackData extends TrackData {
	alpha: number;
	weight: number;
	priority: number;
}

export type CrunchwrapAnimationTrack = AnimationTrackData & interalTrackData;

/**
 * Register the crunchyroll rig along with the player model
 * The limb names in the rig must match the character model's limbs correctly!
 *
 * @param character The character to use
 * @param rig The crunchyroll rig which is accurate to the character
 */
export function register(character: Model, rig: Rig): void;

/**
 * Adds a animation if it is not added yet. If not looped then it will automatically remove it!
 * Info: Fade in/out is not in seconds but in alpha (0 to 1)
 *
 * @param animation The animation to add
 * @param rig The crunchyroll rig
 * @param trackdata Track data
 */
export function add_animation(animation: AnimationAsset, rig: Rig, trackdata: CrunchwrapTrackData): void;

/**
 * Removes an animation with fadeout time (overrides)
 * Track.looped is set to falseWhat happens is that it will fade out
 * Info: Fadeout is not in seconds but in alpha (0 to 1)
 *
 * @param animation The animation to remove
 * @param rig The crunchyroll rig
 * @param fadedata The fade out parameters
 */
export function remove_animation(
	animation: AnimationAsset,
	rig: Rig,
	fadedata: {
		fadetime: number;
		fadecurve?: (alpha: number) => number;
	},
): void;

/**
 * Forcefully remove animation from the rig without fade out
 *
 * @param animation The animation to forcefully remove
 * @param rig The crunchyroll rig
 */
export function force_remove_animation(animation: AnimationAsset, rig: Rig): void;

/**
 * Solves all animations in rigs, and updates the corresponding Motor6Ds in each rig
 *
 * @param dT The timestep
 * @param rigs An array of rigs to update, leave empty to update for all rigs
 */
export function step(dT: number, rigs: Rig[] | undefined): void;

/**
 * Returns the full internal track stored for the animation.
 * Table is mutable, so any changes to anything is reflected realtime
 *
 * @param rig The crunchyroll rig
 * @param animation The animation's track to retrieve
 */
export function retrieve_track(rig: Rig, animation: AnimationAsset): CrunchwrapAnimationTrack | undefined;

export interface curve_preset {
	/**
	 * Crunchwrap's default exponential curve
	 * https://www.desmos.com/calculator/zlussqyagp
	 *
	 * @param alpha 0 to 1 time value of the track
	 * @param k Coefficient
	 * @returns Weight factor
	 */
	exponential: (alpha: number, k: number) => number;
}
