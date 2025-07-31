import React, { forwardRef } from "@rbxts/react";

interface GroupProps extends React.PropsWithChildren {
	anchorPoint?: React.Binding<Vector2> | Vector2;
	change?: React.InstanceChangeEvent<Frame>;
	clipsDescendants?: boolean | React.Binding<boolean>;
	event?: React.InstanceEvent<Frame>;
	layoutOrder?: number | React.Binding<number>;
	position?: React.Binding<UDim2> | UDim2;
	ref?: React.Ref<Frame>;
	rotation?: number | React.Binding<number>;
	size?: React.Binding<UDim2> | UDim2;
	visible?: boolean | React.Binding<boolean>;
	zIndex?: number | React.Binding<number>;
}

export const Group = forwardRef((props: GroupProps, ref: React.Ref<Frame>) => {
	return (
		<frame
			ref={ref}
			Size={props.size || UDim2.fromScale(1, 1)}
			Position={props.position}
			AnchorPoint={props.anchorPoint}
			Rotation={props.rotation}
			ClipsDescendants={props.clipsDescendants}
			LayoutOrder={props.layoutOrder}
			Visible={props.visible}
			ZIndex={props.zIndex}
			BackgroundTransparency={1}
			Event={props.event}
			Change={props.change}
		>
			{props.children}
		</frame>
	);
});
