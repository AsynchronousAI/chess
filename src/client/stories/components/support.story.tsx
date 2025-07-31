import "client/app/react-config";
import { hoarcekat, useMountEffect } from "@rbxts/pretty-react-hooks";
import React from "@rbxts/react";

import { Menu } from "client/components/menu";
import { RootProvider } from "client/providers/root-provider";
import Atoms from "shared/atoms";

export = hoarcekat(() => {
	useMountEffect(() => {
		Atoms.CurrentPage("support");
	});

	return (
		<RootProvider>
			<Menu />
		</RootProvider>
	);
});
