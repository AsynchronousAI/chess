import { useEventListener } from "@rbxts/pretty-react-hooks";
import { useState } from "@rbxts/react";
import { Environment } from "@rbxts/ui-labs";

export default function useMouse() {
	const [mousePosition, setMousePosition] = useState(new Vector2());

	useEventListener(Environment.InputListener.MouseMoved, (newPos) => {
		setMousePosition(newPos);
	});

	return mousePosition;
}
