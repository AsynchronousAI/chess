import { CanvasGroup, Frame, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { usePx } from "./usePx";

export interface EndgamePopupProps {
  title: string;
  description: string;
}

export function EndgamePopup(props: EndgamePopupProps) {
  const px = usePx();
  return (
    <CanvasGroup
      size={new UDim2(0.5, 0.0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      aspectRatio={0.9}
      cornerRadius={px(4)}
      background={"#262421"}
      stroke={{ Color: Color3.fromHex("#3C3A38"), Transparency: 0.5 }}
    >
      <Frame size={new UDim2(1, 0, 0.2, 0)} background={"#3C3A38"} />
      <Text
        text={props.title}
        position={new UDim2(0, 0, 0.02, 0)}
        size={new UDim2(1, 0, 0.1, 0)}
        textSize={px(15)}
        font={"SourceSansBold"}
        noBackground
        textColor={new Color3(1, 1, 1)}
      />
      <Text
        text={props.description}
        position={new UDim2(0, 0, 0.1, 0)}
        size={new UDim2(1, 0, 0.1, 0)}
        textSize={px(8)}
        font={"SourceSansSemibold"}
        noBackground
        textColor={new Color3(0.7, 0.7, 0.7)}
      />
    </CanvasGroup>
  );
}
