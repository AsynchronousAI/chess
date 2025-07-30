import React from "@rbxts/react";

import { Alerts } from "../components/alerts";
import { ErrorHandler } from "../components/error-handler";
import { Menu } from "../components/menu";
import { Music } from "../components/music";
import { Preloader } from "../components/preloader";
import { Stats } from "../components/stats";
import { Layer } from "../components/ui/layer";

export function App() {
	return (
		<ErrorHandler>
			<Music />
			<Preloader />

			<Layer>
				<Menu />
				<Stats />
			</Layer>

			<Layer>
				<Alerts />
			</Layer>
		</ErrorHandler>
	);
}
