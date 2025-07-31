import "client/app/react-config";
import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";

import { RootProvider } from "client/providers/root-provider";
import Board from "client/components/game/board";
import { Menu } from "client/components/menu";
import { Stats } from "client/components/stats";

export = hoarcekat(() => {
	return (
		<RootProvider>
			<Stats />
			<Board />
		</RootProvider>
	);
});
