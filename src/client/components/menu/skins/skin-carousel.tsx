import React, { useEffect } from "@rbxts/react";
import { useSelector } from "@rbxts/react-reflex";
import { Group } from "client/components/ui/group";
import { useRem, useStore } from "client/hooks";
import { selectMenuCurrentSkin } from "client/store/menu";
import { snakeSkins } from "shared/constants/skins";

import { SkinCard } from "./skin-card";
import { DIRECTIONS } from "./utils";

const RANDOM_SKIN = "__random__";

const SKIN_LIST = [RANDOM_SKIN, ...snakeSkins.map((skin) => skin.id)];
const SKIN_LENGTH = SKIN_LIST.size();

export function SkinCarousel() {
	const rem = useRem();
	const store = useStore();

	const skinInventory: string[] = [];
	const equippedSkin = RANDOM_SKIN;
	const currentSkin = useSelector(selectMenuCurrentSkin);

	const currentIndex = SKIN_LIST.indexOf(currentSkin);

	useEffect(() => {
		if (currentSkin === RANDOM_SKIN) {
			store.setMenuSkin(equippedSkin);
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
							store.setMenuSkin(skin);
						}}
					/>
				);
			})}
		</Group>
	);
}
