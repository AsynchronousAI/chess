import React from "@rbxts/react";

import type { FrameProps } from "./frame";

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
}

export function Image(props: ImageProps) {
	return (
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
	);
}
