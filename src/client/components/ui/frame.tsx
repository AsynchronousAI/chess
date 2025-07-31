import type { Ref } from "@rbxts/react";
import React, { forwardRef } from "@rbxts/react";

export interface FrameProps<T extends Instance = Frame> extends React.PropsWithChildren {
	anchorPoint?: React.Binding<Vector2> | Vector2;
	backgroundColor?: Color3 | React.Binding<Color3>;
	backgroundTransparency?: number | React.Binding<number>;
	change?: React.InstanceChangeEvent<T>;
	clipsDescendants?: boolean | React.Binding<boolean>;
	cornerRadius?: React.Binding<UDim> | UDim;
	event?: React.InstanceEvent<T>;
	layoutOrder?: number | React.Binding<number>;
	position?: React.Binding<UDim2> | UDim2;
	ref?: React.Ref<T>;
	rotation?: number | React.Binding<number>;
	size?: React.Binding<UDim2> | UDim2;
	visible?: boolean | React.Binding<boolean>;
	zIndex?: number | React.Binding<number>;
}

export const Frame = forwardRef((props: FrameProps, ref: Ref<Frame>) => {
	return (
		<frame
			ref={ref}
			Size={props.size}
			Position={props.position}
			AnchorPoint={props.anchorPoint}
			Rotation={props.rotation}
			BackgroundColor3={props.backgroundColor}
			BackgroundTransparency={props.backgroundTransparency}
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
		</frame>
	);
});
