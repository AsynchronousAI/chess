import "client/app/react-config";
import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";

import { RootProvider } from "client/providers/root-provider";
import Board from "client/components/game/board";

export = hoarcekat(() => {
	return (
		<RootProvider>
			<Board />
		</RootProvider>
	);
});
