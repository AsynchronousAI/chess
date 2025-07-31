import React from "@rbxts/react";
import { Group } from "client/components/ui/group";
import { useDefined, useRem, useStore } from "client/hooks";
import { formatInteger } from "client/utils/format-integer";

import { StatsCard } from "./stats-card";
import Atoms from "shared/atoms";

export function Stats() {
	const rem = useRem();
	const store = useStore();

	const eliminations = "N/A";
	const score = "N/A";
	const rank = "N/A";
	const balance = 0;

	return (
		<Group>
			<uipadding PaddingBottom={new UDim(0, rem(3))} PaddingLeft={new UDim(0, rem(3))} />

			<uilistlayout
				FillDirection="Vertical"
				HorizontalAlignment="Left"
				VerticalAlignment="Bottom"
				Padding={new UDim(0, rem(1))}
				SortOrder="LayoutOrder"
			/>

			<StatsCard
				emoji="☠️"
				label="KOs"
				value={`${formatInteger(eliminations)}`}
				primary={Color3.fromRGB(161, 163, 194)}
				secondary={Color3.fromRGB(97, 97, 138)}
				enabled={eliminations !== undefined}
				order={0}
			/>

			<StatsCard
				emoji="🏆"
				label="Rank"
				value={rank}
				primary={Color3.fromRGB(255, 203, 80)}
				secondary={Color3.fromRGB(255, 150, 79)}
				enabled={rank !== undefined}
				order={0}
			/>

			<StatsCard
				emoji="💯"
				label="Score"
				value={`${formatInteger(score)}`}
				primary={Color3.fromRGB(181, 64, 64)}
				secondary={Color3.fromRGB(150, 59, 84)}
				enabled={score !== undefined}
				order={1}
			/>

			<StatsCard
				onClick={() => {
					if (score === undefined) {
						// Only show the support page if the user is not playing
						Atoms.CurrentPage("support");
					}
				}}
				emoji="💵"
				label="Cash"
				value={`$${formatInteger(balance)}`}
				primary={Color3.fromRGB(111, 158, 79)}
				secondary={Color3.fromRGB(153, 181, 107)}
				enabled={balance !== undefined}
				order={2}
			/>
		</Group>
	);
}
