import "client/app/react-config";
import { hoarcekat } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";

import { sendAlert } from "client/alerts";
import { Alerts } from "client/components/alerts";
import { Menu } from "client/components/menu";
import { InputCapture } from "client/components/ui/input-capture";
import { RootProvider } from "client/providers/root-provider";
import { palette } from "shared/constants/palette";

export = hoarcekat(() => {
	const modes = ["info", "success", "warning", "error", "awesome"] as const;

	const alert = () => {
		const mode = modes[math.random(0, modes.size() - 1)];

		switch (mode) {
			case "awesome": {
				sendAlert({
					color: palette.mauve,
					colorSecondary: palette.blue,
					emoji: "🎉",
					message: "This is an awesome alert.",
				});
				break;
			}
			case "error": {
				sendAlert({ color: palette.red, emoji: "🚨", message: "This is an error alert." });
				break;
			}
			case "info": {
				sendAlert({ color: palette.blue, emoji: "ℹ️", message: "This is an info alert." });
				break;
			}
			case "success": {
				sendAlert({
					color: palette.green,
					emoji: "✅",
					message: "This is a success alert.",
				});
				break;
			}
			case "warning": {
				sendAlert({
					color: palette.yellow,
					emoji: "⚠️",
					message: "This is a warning alert.",
				});
				break;
			}
		}
	};

	useEffect(() => alert());

	return (
		<RootProvider>
			<Alerts />
			<Menu />
			<InputCapture
				onInputBegan={(_, input) => {
					if (input.KeyCode === Enum.KeyCode.G) {
						alert();
					}
				}}
			/>
		</RootProvider>
	);
});
