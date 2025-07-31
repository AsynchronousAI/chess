import { getBindingValue, useEventListener, useUnmountEffect } from "@rbxts/pretty-react-hooks";
import type { Binding } from "@rbxts/react";
import React, { useMemo, useState } from "@rbxts/react";
import { createPortal } from "@rbxts/react-roblox";
import { RunService } from "@rbxts/services";

import { palette } from "shared/constants/palette";

interface TransitionProps extends React.PropsWithChildren {
	anchorPoint?: Binding<Vector2> | Vector2;
	change?: React.InstanceChangeEvent<CanvasGroup | Frame>;
	children?: React.ReactNode;
	clipsDescendants?: Binding<boolean> | boolean;
	directChildren?: React.ReactNode;
	event?: React.InstanceEvent<CanvasGroup | Frame>;
	groupColor?: Binding<Color3> | Color3;
	groupTransparency?: Binding<number> | number;
	layoutOrder?: Binding<number> | number;
	position?: Binding<UDim2> | UDim2;
	rotation?: Binding<number> | number;
	size?: Binding<UDim2> | UDim2;
	zIndex?: Binding<number> | number;
}

const EPSILON = 0.03;

export function Transition({
	anchorPoint,
	change,
	children,
	clipsDescendants,
	directChildren,
	event,
	groupColor,
	groupTransparency,
	layoutOrder,
	position,
	rotation,
	size = new UDim2(1, 0, 1, 0),
	zIndex,
}: TransitionProps) {
	const [frame, setFrame] = useState<Frame>();
	const [canvas, setCanvas] = useState<CanvasGroup>();

	const container = useMemo(() => {
		const container = new Instance("Frame");
		container.Size = new UDim2(1, 0, 1, 0);
		container.BackgroundTransparency = 1;
		return container;
	}, []);

	useEventListener(RunService.Heartbeat, () => {
		const transparency = getBindingValue(groupTransparency) ?? 0;
		const color = getBindingValue(groupColor) || palette.white;

		pcall(() => {
			container.Parent = transparency > EPSILON || color !== palette.white ? canvas : frame;
		});
	});

	useUnmountEffect(() => {
		container.Destroy();
	});

	return (
		<frame
			BackgroundTransparency={1}
			AnchorPoint={anchorPoint}
			Size={size}
			Position={position}
			Rotation={rotation}
			LayoutOrder={layoutOrder}
			ZIndex={zIndex}
		>
			{createPortal(<>{children}</>, container)}

			<canvasgroup
				ref={setCanvas}
				Change={change}
				Event={event}
				GroupTransparency={groupTransparency}
				GroupColor3={groupColor}
				BackgroundTransparency={1}
				Size={new UDim2(1, 0, 1, 0)}
			>
				{directChildren}
			</canvasgroup>

			<frame
				ref={setFrame}
				Change={change}
				Event={event}
				ClipsDescendants={clipsDescendants}
				BackgroundTransparency={1}
				Size={new UDim2(1, 0, 1, 0)}
			>
				{directChildren}
			</frame>
		</frame>
	);
}
