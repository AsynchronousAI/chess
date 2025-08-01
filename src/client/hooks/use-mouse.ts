import { useEventListener } from "@rbxts/pretty-react-hooks";
import { useBinding, useState } from "@rbxts/react";
import { Players, RunService, UserInputService } from "@rbxts/services";
import { Environment } from "@rbxts/ui-labs";

export default function useMouse() {
	const [mousePosition, setMousePosition] = useBinding(new Vector2());

	if (!RunService.IsRunning()) {
		/* in story */
		useEventListener(Environment.InputListener?.MouseMoved, (newPos) => {
			setMousePosition(newPos);
		});
	} else {
		const mouse = Players.LocalPlayer.GetMouse();
		useEventListener(mouse.Move, () => {
			setMousePosition(new Vector2(mouse.X, mouse.Y));
		});
	}

	return mousePosition;
}
