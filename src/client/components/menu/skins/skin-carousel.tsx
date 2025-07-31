import React, { useEffect } from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";

import { Group } from "client/components/ui/group";
import { useRem } from "client/hooks";
import Atoms from "shared/atoms";
import { snakeSkins } from "shared/constants/skins";

import { SkinCard } from "./skin-card";
import { DIRECTIONS } from "./utils";

const RANDOM_SKIN = "__random__";

const SKIN_LIST = [RANDOM_SKIN, ...snakeSkins.map((skin) => skin.id)];
const SKIN_LENGTH = SKIN_LIST.size();

export function SkinCarousel() {
	const rem = useRem();

	const skinInventory: Array<string> = [];
	const equippedSkin = RANDOM_SKIN;
	const currentSkin = useAtom(Atoms.FocusedSkin);

	const currentIndex = SKIN_LIST.indexOf(currentSkin);

	useEffect(() => {
		if (currentSkin === RANDOM_SKIN) {
			Atoms.FocusedSkin(equippedSkin);
		}
	}, []);

	return (
		<Group size={new UDim2(1, 0, 1, -rem(3))}>
			{DIRECTIONS.map((direction) => {
				const index = (currentIndex + direction) % SKIN_LENGTH;
				const skin = SKIN_LIST[index] ?? RANDOM_SKIN;

				return (
					<SkinCard
						key={skin}
						id={skin}
						index={direction}
						active={skin === currentSkin}
						shuffle={skin === RANDOM_SKIN ? skinInventory : undefined}
						onClick={() => {
							Atoms.FocusedSkin(skin);
						}}
					/>
				);
			})}
		</Group>
	);
}
