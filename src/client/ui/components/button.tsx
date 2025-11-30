import React from "@rbxts/react";
import { usePx } from "../hooks/usePx";
import { Frame, Image, Text } from "@rbxts/better-react-components";
import { useMotion } from "@rbxts/pretty-react-hooks";

const DEFAULT_BORDER = new Color3(0.5, 0.5, 0.5);
const FOCUSED_BORDER = new Color3(1, 1, 1);

export function Button({
  title,
  image,
  callback,
  aspectRatio,
}: {
  title: string;
  image: string;
  callback: () => void;
  aspectRatio?: number;
}) {
  const px = usePx();
  const [borderColor, borderColorMotion] = useMotion(DEFAULT_BORDER);
  return (
    <Frame
      size={new UDim2(0.3, 0, 0.2, 0)}
      aspectRatio={aspectRatio ?? 2}
      cornerRadius={px(10)}
      background={"#403E39"}
      visible={true}
      stroke={{ Color: borderColor, Thickness: px(1), Transparency: 0.5 }}
    >
      <Image
        size={new UDim2(0.45, 0, 0.45, 0)}
        anchorPoint={new Vector2(0, 0.5)}
        position={new UDim2(0.1, 0, 0.5, 0)}
        imageColor={new Color3(0.75, 0.75, 0.75)}
        noBackground
        aspectRatio={1}
        image={image}
      />
      <Text
        automaticSize={"X"}
        text={title}
        size={new UDim2(1, 0, 1, 0)}
        position={new UDim2(0, px(5), 0, 0)}
        font={"SourceSansSemibold"}
        textColor={new Color3(0.75, 0.75, 0.75)}
        noBackground
        overrideRoblox={{ TextScaled: true }}
        padding={new UDim(0.25, 0)}
        paddingLeft={new UDim(0.3, 0)}
      />
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        BackgroundTransparency={1}
        Text=""
        Event={{
          MouseButton1Click: () => callback(),
          MouseEnter: () => {
            borderColorMotion.spring(FOCUSED_BORDER);
          },
          MouseLeave: () => {
            borderColorMotion.spring(DEFAULT_BORDER);
          },
        }}
      />
    </Frame>
  );
}
