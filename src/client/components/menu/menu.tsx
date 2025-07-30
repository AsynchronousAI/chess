import React, { useEffect } from "@rbxts/react";
import { useStore } from "client/hooks";

import { Home } from "./home";
import { MenuContainer } from "./menu-container";
import { MenuVignette } from "./menu-vignette";
import { Navigation } from "./navigation";
import { Skins } from "./skins";
import { Support } from "./support";

export function Menu() {
	const store = useStore();
	useEffect(() => {
		store.setMenuOpen(true);
	}, []);

	return (
		<>
			<MenuVignette />

			<MenuContainer>
				<Navigation />
			</MenuContainer>

			<MenuContainer page="home">
				<Home />
			</MenuContainer>

			<MenuContainer page="support">
				<Support />
			</MenuContainer>

			<MenuContainer page="skins">
				<Skins />
			</MenuContainer>
		</>
	);
}
