import "client/app/react-config";
import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React from "@rbxts/react";

import { Menu } from "client/components/menu";
import { RootProvider } from "client/providers/root-provider";

export = hoarcekat(() => {
	return (
		<RootProvider>
			<Menu />
		</RootProvider>
	);
});
