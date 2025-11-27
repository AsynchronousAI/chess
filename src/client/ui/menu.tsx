import { Frame, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { usePx } from "./hooks/usePx";
import { Button } from "./components/button";

export function Menu() {
  const px = usePx();
  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
    >
      <uilistlayout
        FillDirection={"Vertical"}
        VerticalAlignment={"Top"}
        HorizontalAlignment={"Center"}
      />
      <Text
        text={"Chess"}
        size={new UDim2(1, 0, 0.25, 0)}
        noBackground
        font={"SourceSansBold"}
        padding={new UDim(0.2, 0)}
        overrideRoblox={{ TextScaled: true }}
        textColor={new Color3(1, 1, 1)}
      />
      <Button
        title={"Resign"}
        image={"rbxassetid://10723375890"}
        callback={() => void 0}
        aspectRatio={3}
      />
    </Frame>
  );
}
