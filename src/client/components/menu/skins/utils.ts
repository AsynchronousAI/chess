import { useInterval } from "@rbxts/pretty-react-hooks";
import { useState } from "@rbxts/react";

import type { SnakeSkin } from "shared/constants/skins";
import { getSnakeSkin } from "shared/constants/skins";
import { darken } from "shared/utils/color-utils";

export interface SnakePalette {
	readonly primary: Color3;
	readonly secondary: Color3;
	readonly skin: SnakeSkin;
}

export const DIRECTIONS = [-3, -2, -1, 0, 1, 2, 3];
export const DIRECTIONS_TO_HIDE = [-3, 3];

export function usePalette(id: string, shuffle?: ReadonlyArray<string>): SnakePalette {
	const [skin, setSkin] = useState(getSnakeSkin(id));

	useInterval(() => {
		if (shuffle && !shuffle.isEmpty()) {
			const skinId = shuffle[math.random(0, shuffle.size() - 1)];
			setSkin(getSnakeSkin(skinId));
		}
	}, 1);

	return {
		primary: skin.primary || darken(skin.tint[0], 0.5, 0.4),
		secondary: skin.secondary || darken(skin.tint[0], 0.7, 0.4),
		skin,
	};
}
