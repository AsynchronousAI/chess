import React, { useEffect, useState } from "@rbxts/react";
import { setTimeout } from "@rbxts/set-timeout";

interface DelayRenderProps extends React.PropsWithChildren {
	mountDelay?: number;
	shouldRender: boolean;
	unmountDelay?: number;
}

export function DelayRender({
	children,
	mountDelay = 0,
	shouldRender,
	unmountDelay = 0,
}: DelayRenderProps) {
	const [render, setRender] = useState(false);

	useEffect(() => {
		return setTimeout(
			() => {
				setRender(shouldRender);
			},
			shouldRender ? mountDelay : unmountDelay,
		);
	}, [shouldRender]);

	return <>{render && children}</>;
}
