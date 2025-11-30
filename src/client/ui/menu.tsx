import { Frame, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { usePx } from "./hooks/usePx";
import { Button } from "./components/button";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import { RunService } from "@rbxts/services";

export function Menu() {
  const gameplay = RunService.IsRunning()
    ? useFlameworkDependency<Gameplay>()
    : undefined;

  const activeGame = gameplay?.useActiveGame();
  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
      visible={activeGame?.opening === undefined}
    >
      <uilistlayout
        FillDirection={"Vertical"}
        VerticalAlignment={"Top"}
        Padding={new UDim(0.05, 0)}
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
        title={"vs Bot"}
        image={"rbxassetid://10709782230"}
        callback={() => gameplay?.newGame(true)}
        aspectRatio={3}
        size={new UDim2(1, 0, 0.15, 0)}
      />
      <Button
        title={"vs Player"}
        image={"rbxassetid://10747373176"}
        callback={() => gameplay?.newGame(false)}
        aspectRatio={3}
        size={new UDim2(1, 0, 0.15, 0)}
      />
    </Frame>
  );
}
