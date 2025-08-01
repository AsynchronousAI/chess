import "client/app/react-config";
import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";

import { RootProvider } from "client/providers/root-provider";
import Board from "client/components/game/board";
import { Menu } from "client/components/menu";
import { Stats } from "client/components/stats";
import { InputCapture } from "client/components/ui/input-capture";
import Atoms from "shared/atoms";

export = hoarcekat(() => {
	useEffect(() => {
		Atoms.IsMenuOpen(false);
	});
	return (
		<RootProvider>
			<InputCapture
				onInputBegan={(_, input) => {
					if (input.KeyCode === Enum.KeyCode.G) {
						Atoms.PlayingAs((prev) => (prev === "white" ? "black" : "white"));
					}
				}}
			/>
			<Stats />
			<Board />
		</RootProvider>
	);
});
