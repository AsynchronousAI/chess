import React from "@rbxts/react";

import type { FrameProps } from "./frame";
import { useBindingState } from "@rbxts/pretty-react-hooks";

export interface ImageProps extends FrameProps<ImageLabel> {
	image: string;
	imageColor?: Color3 | React.Binding<Color3>;
	imageRectOffset?: React.Binding<Vector2> | Vector2;
	imageRectSize?: React.Binding<Vector2> | Vector2;
	imageTransparency?: number | React.Binding<number>;
	scaleType?: React.InferEnumNames<Enum.ScaleType>;
	sliceCenter?: React.Binding<Rect> | Rect;
	sliceScale?: number | React.Binding<number>;
	tileSize?: React.Binding<UDim2> | UDim2;

	/** @see: https://devforum.roblox.com/t/uistroke-outlines-for-ui-images/747932/11?u=bitsplicer */
	outlineStartAngle?: number;
	outlineThickness?: number;
	outlinePrecision?: number;
	outlineColor?: Color3;
}

export function Image(props: ImageProps) {
	const elements: React.Element[] = [];

	if (props.outlineStartAngle && props.outlinePrecision && props.outlineThickness) {
		for (let i = props.outlineStartAngle; i < props.outlineStartAngle + 360; i += props.outlinePrecision) {
			const angle = math.rad(i);
			const offset = new UDim2(
				0,
				math.sin(angle) * props.outlineThickness,
				0,
				math.cos(angle) * props.outlineThickness,
			);

			elements.push(
				<imagelabel
					key={`Stroke${i}`}
					Image={props.image}
					Size={props.size}
					Position={props.position ? useBindingState(props.position).add(offset) : offset}
					ZIndex={props.zIndex ? useBindingState(props.zIndex) - 1 : -1}
					ImageColor3={props.outlineColor}
					BackgroundTransparency={1}
					ImageTransparency={props.imageTransparency}
					ImageRectOffset={props.imageRectOffset}
					ImageRectSize={props.imageRectSize}
					ScaleType={props.scaleType}
					SliceScale={props.sliceScale}
					SliceCenter={props.sliceCenter}
					TileSize={props.tileSize}
					AnchorPoint={props.anchorPoint}
					Rotation={props.rotation}
					BackgroundColor3={props.backgroundColor}
					ClipsDescendants={props.clipsDescendants}
					Visible={props.visible}
					LayoutOrder={props.layoutOrder}
				/>,
			);
		}
	}

	return (
		<>
			{elements}
			<imagelabel
				Image={props.image}
				ImageColor3={props.imageColor}
				ImageTransparency={props.imageTransparency}
				ImageRectOffset={props.imageRectOffset}
				ImageRectSize={props.imageRectSize}
				ScaleType={props.scaleType}
				SliceScale={props.sliceScale}
				SliceCenter={props.sliceCenter}
				TileSize={props.tileSize}
				Size={props.size}
				Position={props.position}
				AnchorPoint={props.anchorPoint}
				Rotation={props.rotation}
				BackgroundColor3={props.backgroundColor}
				BackgroundTransparency={props.backgroundTransparency ?? 1}
				ClipsDescendants={props.clipsDescendants}
				Visible={props.visible}
				ZIndex={props.zIndex}
				LayoutOrder={props.layoutOrder}
				BorderSizePixel={0}
				Event={props.event}
				Change={props.change}
			>
				{props.children}
				{props.cornerRadius && <uicorner CornerRadius={props.cornerRadius} />}
			</imagelabel>
		</>
	);
}
