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
    <frame
      Size={new UDim2(1, 0, 1, 0)}
      Position={new UDim2(0.5, 0, 0.5, 0)}
      AnchorPoint={new Vector2(0.5, 0.5)}
      BackgroundColor3={new Color3(0.1, 0.1, 0.1)}
      Visible={activeGame?.opening === undefined}
      BorderSizePixel={0}
    >
      <uilistlayout
        FillDirection={"Vertical"}
        VerticalAlignment={"Top"}
        Padding={new UDim(0.05, 0)}
        HorizontalAlignment={"Center"}
      />
      <textlabel
        Text={"Chess"}
        Size={new UDim2(1, 0, 0.25, 0)}
        BackgroundTransparency={1}
        Font={Enum.Font.SourceSansBold}
        TextScaled={true}
        TextColor3={new Color3(1, 1, 1)}
      >
        <uipadding
          PaddingTop={new UDim(0.2, 0)}
          PaddingBottom={new UDim(0.2, 0)}
          PaddingLeft={new UDim(0.2, 0)}
          PaddingRight={new UDim(0.2, 0)}
        />
      </textlabel>
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
    </frame>
  );
}
