import { useEventListener, useLatest } from "@rbxts/pretty-react-hooks";
import { useMemo, useState } from "@rbxts/react";
import { UserInputService } from "@rbxts/services";
import { setTimeout } from "@rbxts/set-timeout";

import { useInputDevice } from "../../../hooks/use-input-device";

export interface ButtonEvents {
	onMouseDown: () => void;
	onMouseEnter: () => void;
	onMouseLeave: () => void;
	onMouseUp: () => void;
}

/**
 * Returns the current state of a button based on the events returned.
 * @param enabled - Whether the button is enabled or not.
 * @returns The press state, hover state, and a `ButtonEvents` object.
 */
export function useButtonState(enabled = true): LuaTuple<[press: boolean, hover: boolean, events: ButtonEvents]> {
	const [{ hover, press }, setState] = useState({
		hover: false,
		press: false,
	});

	const on = useLatest(enabled);
	const touch = useLatest(useInputDevice() === "touch");

	const events: ButtonEvents = useMemo(() => {
		return {
			onMouseDown: () => { setState((state) => ({ ...state, press: on.current })); },
			onMouseEnter: () => { setState((state) => ({ ...state, hover: on.current && !touch.current })); },
			onMouseLeave: () => { setState({ hover: false, press: false }); },
			onMouseUp: () => { setState((state) => ({ ...state, press: false })); },
		};
	}, []);

	// Touch devices might not fire mouse leave events, so assume that all
	// releases are a mouse leave.
	useEventListener(UserInputService.InputEnded, (input) => {
		if (input.UserInputType === Enum.UserInputType.Touch) {
			setTimeout(() => {
				setState({ hover: false, press: false });
			}, 0);
		}
	});

	return $tuple(press, hover, events);
}
