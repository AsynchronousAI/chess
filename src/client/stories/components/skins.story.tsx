import "client/app/react-config";

import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";
import { Alerts } from "client/components/alerts";
import { Menu } from "client/components/menu";
import { RootProvider } from "client/providers/root-provider";
import Atoms from "shared/atoms";

export = hoarcekat(() => {
	useEffect(() => {
		Atoms.CurrentPage("skins");
	});
	return (
		<RootProvider>
			<Menu />
			<Alerts />
		</RootProvider>
	);
});
