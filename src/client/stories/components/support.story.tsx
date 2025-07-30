import "client/app/react-config";

import { hoarcekat, useMountEffect } from "@rbxts/pretty-react-hooks";
import React from "@rbxts/react";
import { Menu } from "client/components/menu";
import { RootProvider } from "client/providers/root-provider";
import { store } from "client/store";
import { USER_NAME } from "shared/constants/core";
import { defaultPlayerSave } from "shared/store/saves";

export = hoarcekat(() => {
	useMountEffect(() => {
		store.setMenuPage("support");
		store.setPlayerSave(USER_NAME, {
			...defaultPlayerSave,
			balance: 0,
		});
	});

	return (
		<RootProvider>
			<Menu />
		</RootProvider>
	);
});
