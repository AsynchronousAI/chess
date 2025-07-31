import { blend, composeBindings, lerpBinding, useUpdateEffect } from "@rbxts/pretty-react-hooks";
import React from "@rbxts/react";

import { useMotion, useRem } from "client/hooks";
import type { ButtonSoundVariant } from "shared/assets";
import { playButtonDown, playButtonUp } from "shared/assets";

import { Button } from "../button";
import { Frame } from "../frame";
import { useButtonAnimation } from "./use-button-animation";
import { useButtonState } from "./use-button-state";

interface ReactiveButtonProps extends React.PropsWithChildren {
	anchorPoint?: React.Binding<Vector2> | Vector2;
	animatePosition?: boolean;
	animatePositionDirection?: Vector2;
	animatePositionStrength?: number;
	animateSize?: boolean;
	animateSizeStrength?: number;
	backgroundColor?: Color3 | React.Binding<Color3>;
	backgroundTransparency?: number | React.Binding<number>;
	change?: React.InstanceChangeEvent<TextButton>;
	cornerRadius?: React.Binding<UDim> | UDim;
	enabled?: boolean;
	event?: React.InstanceEvent<TextButton>;
	layoutOrder?: number | React.Binding<number>;
	onClick?: () => void;
	onHover?: (hovered: boolean) => void;
	onMouseDown?: () => void;
	onMouseEnter?: () => void;
	onMouseLeave?: () => void;
	onMouseUp?: () => void;
	onPress?: (pressed: boolean) => void;
	position?: React.Binding<UDim2> | UDim2;
	size?: React.Binding<UDim2> | UDim2;
	soundVariant?: ButtonSoundVariant;
	zIndex?: number | React.Binding<number>;
}

export function ReactiveButton({
	anchorPoint,
	animatePosition = true,
	animatePositionDirection = new Vector2(0, 1),
	animatePositionStrength = 1,
	animateSize = true,
	animateSizeStrength = 1,
	backgroundColor = Color3.fromRGB(255, 255, 255),
	backgroundTransparency = 0,
	change,
	children,
	cornerRadius,
	enabled = true,
	event,
	layoutOrder,
	onClick,
	onHover,
	onMouseDown,
	onMouseEnter,
	onMouseLeave,
	onMouseUp,
	onPress,
	position,
	size,
	soundVariant = "default",
	zIndex,
}: ReactiveButtonProps) {
	const rem = useRem();
	const [sizeAnimation, sizeMotion] = useMotion(0);
	const [press, hover, buttonEvents] = useButtonState();
	const animation = useButtonAnimation(press, hover);

	useUpdateEffect(() => {
		if (press) {
			sizeMotion.spring(-0.1, { tension: 300 });
		} else {
			sizeMotion.spring(0, { impulse: 0.01, tension: 300 });
		}
	}, [press]);

	useUpdateEffect(() => {
		onHover?.(hover);
	}, [hover]);

	useUpdateEffect(() => {
		onPress?.(press);
	}, [press]);

	return (
		<Button
			onClick={enabled ? onClick : undefined}
			active={enabled}
			onMouseDown={() => {
				if (!enabled) {
					return;
				}

				buttonEvents.onMouseDown();
				onMouseDown?.();
				playButtonDown(soundVariant);
			}}
			onMouseUp={() => {
				if (!enabled) {
					return;
				}

				buttonEvents.onMouseUp();
				onMouseUp?.();
				playButtonUp(soundVariant);
			}}
			onMouseEnter={() => {
				buttonEvents.onMouseEnter();
				onMouseEnter?.();
			}}
			onMouseLeave={() => {
				buttonEvents.onMouseLeave();
				onMouseLeave?.();
			}}
			backgroundTransparency={1}
			size={size}
			position={position}
			anchorPoint={anchorPoint}
			layoutOrder={layoutOrder}
			zIndex={zIndex}
			event={event}
			change={change}
		>
			<Frame
				backgroundColor={composeBindings(
					animation.hoverOnly,
					animation.press,
					backgroundColor,
					(hover, press, color) => {
						return color
							.Lerp(new Color3(1, 1, 1), hover * 0.15)
							.Lerp(new Color3(), press * 0.1);
					},
				)}
				backgroundTransparency={composeBindings(
					animation.press,
					backgroundTransparency,
					(press, transparency) => blend(-press * 0.2, transparency),
				)}
				cornerRadius={cornerRadius}
				anchorPoint={new Vector2(0.5, 0.5)}
				size={lerpBinding(
					animateSize ? sizeAnimation : 0,
					new UDim2(1, 0, 1, 0),
					new UDim2(1, rem(2 * animateSizeStrength), 1, rem(2 * animateSizeStrength)),
				)}
				position={lerpBinding(
					animatePosition ? animation.position : 0,
					new UDim2(0.5, 0, 0.5, 0),
					new UDim2(
						0.5,
						(3 + rem(0.1)) * animatePositionStrength * animatePositionDirection.X,
						0.5,
						(3 + rem(0.1)) * animatePositionStrength * animatePositionDirection.Y,
					),
				)}
			>
				{children}
			</Frame>
		</Button>
	);
}
