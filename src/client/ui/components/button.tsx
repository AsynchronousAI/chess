import React from "@rbxts/react";
import { usePx } from "../hooks/usePx";
import { useMotion } from "@rbxts/pretty-react-hooks";

const DEFAULT_BORDER = new Color3(0.5, 0.5, 0.5);
const FOCUSED_BORDER = new Color3(1, 1, 1);

export function Button({
  title,
  image,
  callback,
  aspectRatio,
  size,
}: {
  title: string;
  image: string;
  callback: () => void;
  aspectRatio?: number;
  size?: UDim2;
}) {
  const px = usePx();
  const [borderColor, borderColorMotion] = useMotion(DEFAULT_BORDER);
  return (
    <frame
      Size={size ?? new UDim2(0.3, 0, 0.2, 0)}
      Visible={true}
      BackgroundColor3={Color3.fromHex("#403E39")}
      BorderSizePixel={0}
    >
      <uiaspectratioconstraint AspectRatio={aspectRatio ?? 2} />
      <uicorner CornerRadius={new UDim(0, px(10))} />
      <uistroke Color={borderColor} Thickness={px(1)} Transparency={0.5} />
      <imagelabel
        Size={new UDim2(0.45, 0, 0.45, 0)}
        AnchorPoint={new Vector2(0, 0.5)}
        Position={new UDim2(0.1, 0, 0.5, 0)}
        ImageColor3={new Color3(0.75, 0.75, 0.75)}
        BackgroundTransparency={1}
        Image={image}
      >
        <uiaspectratioconstraint AspectRatio={1} />
      </imagelabel>
      <textlabel
        AutomaticSize={Enum.AutomaticSize.X}
        Text={title}
        Size={new UDim2(1, 0, 1, 0)}
        Position={new UDim2(0, px(5), 0, 0)}
        Font={Enum.Font.SourceSansSemibold}
        TextColor3={new Color3(0.75, 0.75, 0.75)}
        BackgroundTransparency={1}
        TextScaled={true}
      >
        <uipadding
          PaddingTop={new UDim(0.25, 0)}
          PaddingBottom={new UDim(0.25, 0)}
          PaddingRight={new UDim(0.25, 0)}
          PaddingLeft={new UDim(0.3, 0)}
        />
      </textlabel>
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
    </frame>
  );
}
