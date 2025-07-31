import { SoundService } from "@rbxts/services";

import { IS_EDIT } from "shared/constants/core";

export interface SoundOptions {
	looped?: boolean;
	parent?: Instance;
	speed?: number;
	volume?: number;
}

export function createSound(
	soundId: string,
	{ looped = false, parent = SoundService, speed = 1, volume = 0.5 }: SoundOptions = {},
) {
	const sound = new Instance("Sound");

	sound.SoundId = soundId;
	sound.Volume = volume;
	sound.PlaybackSpeed = speed;
	sound.Looped = looped;
	sound.Parent = parent;

	return sound;
}

export function playSound(soundId: string, options?: SoundOptions) {
	if (IS_EDIT) {
		return;
	}

	const sound = createSound(soundId, options);

	sound.Ended.Connect(() => {
		sound.Destroy();
	});
	sound.Play();

	return sound;
}
