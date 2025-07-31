import React, { useEffect } from "@rbxts/react";

import Atoms from "shared/atoms";

import { Home } from "./home";
import { MenuContainer } from "./menu-container";
import { MenuVignette } from "./menu-vignette";
import { Navigation } from "./navigation";
import { Skins } from "./skins";
import { Support } from "./support";

export function Menu() {
	useEffect(() => {
		Atoms.IsMenuOpen(true);
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
