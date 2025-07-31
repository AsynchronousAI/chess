import { useEventListener } from "@rbxts/pretty-react-hooks";
import { useBinding, useState } from "@rbxts/react";
import { Environment } from "@rbxts/ui-labs";

export default function useMouse() {
	const [mousePosition, setMousePosition] = useBinding(new Vector2());

	useEventListener(Environment.InputListener.MouseMoved, (newPos) => {
		setMousePosition(newPos);
	});

	return mousePosition;
}
