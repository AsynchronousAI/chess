import React from "@rbxts/react";

import { useBindingState } from "@rbxts/pretty-react-hooks";
export interface ImageProps<T extends Instance = ImageLabel>
  extends React.PropsWithChildren {
  // FrameProps
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

  // Image-specific
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

  if (
    props.outlineStartAngle &&
    props.outlinePrecision &&
    props.outlineThickness
  ) {
    for (
      let i = props.outlineStartAngle;
      i < props.outlineStartAngle + 360;
      i += props.outlinePrecision
    ) {
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
          Size={new UDim2(1, 0, 1, 0)}
          Position={offset}
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
    <frame
      Size={props.size}
      Position={props.position}
      BackgroundTransparency={1}
    >
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
        Size={new UDim2(1, 0, 1, 0)}
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
    </frame>
  );
}
