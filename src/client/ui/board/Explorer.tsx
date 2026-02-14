import React from "@rbxts/react";
import { usePx } from "../hooks/usePx";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import { RunService } from "@rbxts/services";
import { Button } from "../components/button";
import { Move } from "shared/engine/move";

export interface ExplorerProps {
  opening: string;
  currentMove: number;
  position: UDim2;
  onRewind: (index: number, backwards?: boolean) => void;
}
export function Explorer({
  opening,
  currentMove,
  onRewind,
  position,
}: ExplorerProps) {
  const gameplay = RunService.IsRunning()
    ? useFlameworkDependency<Gameplay>()
    : undefined;
  const moveHistory = gameplay?.useMoveHistory() ?? [];
  const px = usePx();

  return (
    <canvasgroup
      Size={new UDim2(0.25, 0, 0.975, 0)}
      Position={position}
      AnchorPoint={new Vector2(0.5, 0.5)}
      BackgroundColor3={new Color3(0.1, 0.1, 0.1)}
      BorderSizePixel={0}
    >
      <uicorner CornerRadius={new UDim(0, px(2))} />
      <uilistlayout
        FillDirection={"Horizontal"}
        Wraps
        VerticalAlignment={"Top"}
        HorizontalAlignment={"Center"}
        Padding={new UDim(0, px(10))}
        SortOrder={"LayoutOrder"}
      />
      <scrollingframe
        LayoutOrder={0}
        BackgroundTransparency={1}
        Size={new UDim2(1, 0, 0.85, 0)}
        CanvasSize={new UDim2(1, 0, 0, 0)}
        TopImage={"rbxassetid://3062506215"}
        BottomImage={"rbxassetid://3062506215"}
        MidImage={"rbxassetid://3062506215"}
        ScrollBarImageTransparency={0.5}
        ScrollBarImageColor3={new Color3(1, 1, 1)}
        ScrollingDirection={Enum.ScrollingDirection.Y}
        AutomaticCanvasSize={Enum.AutomaticSize.Y}
        BorderSizePixel={0}
      >
        <uilistlayout
          FillDirection={Enum.FillDirection.Vertical}
          VerticalAlignment={Enum.VerticalAlignment.Top}
          HorizontalAlignment={Enum.HorizontalAlignment.Center}
          SortOrder={Enum.SortOrder.LayoutOrder}
        />
        <textlabel
          BackgroundColor3={Color3.fromHex("#403E39")}
          Text={opening}
          TextColor3={new Color3(1, 1, 1)}
          TextSize={px(20)}
          Font={Enum.Font.SourceSansSemibold}
          Size={new UDim2(1, 0, 0, px(45))}
          LayoutOrder={0}
          BorderSizePixel={0}
        />

        {moveHistory
          .filter((_, i) => i % 2 === 0) // only white moves, since black moves will be displayed same place
          .map((move, minimizedIndex) => {
            const index = minimizedIndex * 2;
            const blackResponse = moveHistory[index + 1];
            return (
              <frame
                LayoutOrder={minimizedIndex}
                Size={new UDim2(1, 0, 0, px(35))}
                BackgroundColor3={
                  minimizedIndex % 2 === 0
                    ? Color3.fromHex("#403E39")
                    : Color3.fromHex("#282723")
                }
                key={minimizedIndex}
                BackgroundTransparency={0.5}
                BorderSizePixel={0}
              >
                <uipadding
                  PaddingTop={new UDim(0, px(5))}
                  PaddingBottom={new UDim(0, px(5))}
                  PaddingRight={new UDim(0, px(5))}
                  PaddingLeft={new UDim(0, px(10))}
                />
                <uilistlayout
                  FillDirection={Enum.FillDirection.Horizontal}
                  VerticalAlignment={Enum.VerticalAlignment.Center}
                  HorizontalAlignment={Enum.HorizontalAlignment.Left}
                  SortOrder={Enum.SortOrder.LayoutOrder}
                  Padding={new UDim(0, px(15))}
                />
                <textlabel
                  Text={`${minimizedIndex + 1}.`}
                  TextColor3={new Color3(0.6, 0.6, 0.6)}
                  TextSize={px(20)}
                  Font={Enum.Font.SourceSansSemibold}
                  TextXAlignment={Enum.TextXAlignment.Left}
                  Size={new UDim2(0.05, 0, 1, 0)}
                  BackgroundTransparency={1}
                />

                {/* White move */}
                <textbutton
                  Text={Move.toString(move.move)}
                  TextColor3={
                    index === currentMove
                      ? new Color3(1, 1, 1)
                      : new Color3(0.8, 0.8, 0.8)
                  }
                  TextSize={px(20)}
                  Font={Enum.Font.SourceSansSemibold}
                  Size={new UDim2(0, 0, 1, 0)}
                  AutomaticSize={Enum.AutomaticSize.X}
                  BackgroundTransparency={1}
                  Event={{
                    MouseButton1Click: () => onRewind(index),
                  }}
                />

                {/* Black move */}
                {blackResponse !== undefined && (
                  <textbutton
                    Text={Move.toString(blackResponse.move)}
                    TextColor3={
                      index + 1 === currentMove
                        ? new Color3(1, 1, 1)
                        : new Color3(0.8, 0.8, 0.8)
                    }
                    TextSize={px(20)}
                    Font={Enum.Font.SourceSansSemibold}
                    Size={new UDim2(0, 0, 1, 0)}
                    AutomaticSize={Enum.AutomaticSize.X}
                    BackgroundTransparency={1}
                    Event={{
                      MouseButton1Click: () => onRewind(index + 1),
                    }}
                  />
                )}
              </frame>
            );
          })}
      </scrollingframe>
      {/*
      <Button
        title={"Resign"}
        image={"rbxassetid://10723375890"}
        callback={() => gameplay?.resign()}
      />
      <Button
        title={"Draw"}
        image={"rbxassetid://13738539975"}
        callback={() => gameplay?.draw()}
      />*/}
    </canvasgroup>
  );
}
