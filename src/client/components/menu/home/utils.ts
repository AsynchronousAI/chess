import Object from "@rbxts/object-utils";
import { palette } from "shared/constants/palette";

function generate(colors: Array<Color3>) {
	const sequence: Array<ColorSequenceKeypoint> = [];
	const length = colors.size();

	for (const [index, color] of Object.entries(colors)) {
		sequence.push(new ColorSequenceKeypoint(index / (length - 1), color));
	}

	return new ColorSequence(sequence);
}

export const gradient = generate([palette.red, palette.yellow, palette.teal, palette.blue, palette.mauve]);

export const gradientPinched = generate([
	palette.red,
	palette.red,
	palette.yellow,
	palette.teal,
	palette.blue,
	palette.mauve,
	palette.mauve,
]);
