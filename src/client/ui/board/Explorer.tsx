import {
  CanvasGroup,
  Frame,
  ListLayout,
  ScrollingFrame,
  Text,
} from "@rbxts/better-react-components";
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
    <CanvasGroup
      size={new UDim2(0.25, 0, 0.975, 0)}
      position={position}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
      cornerRadius={px(2)}
    >
      <uilistlayout
        FillDirection={"Horizontal"}
        Wraps
        VerticalAlignment={"Top"}
        HorizontalAlignment={"Center"}
        Padding={new UDim(0, px(10))}
        SortOrder={"LayoutOrder"}
      />
      <ScrollingFrame
        layoutOrder={0}
        noBackground
        size={new UDim2(1, 0, 0.85, 0)}
        canvasSize={new UDim2(1, 0, 0, 0)}
        scrollbar={{
          topImage: "rbxassetid://3062506215",
          bottomImage: "rbxassetid://3062506215",
          midImage: "rbxassetid://3062506215",
          imageTransparency: 0.5,
          imageColor: new Color3(1, 1, 1),
        }}
        direction={"Y"}
        automaticCanvasSize={"Y"}
      >
        <ListLayout
          direction={"Vertical"}
          verticalAlign={"Top"}
          horizontalAlign={"Center"}
          order={"LayoutOrder"}
        />
        <Text
          background={"#403E39"}
          text={opening}
          textColor={new Color3(1, 1, 1)}
          textSize={px(20)}
          font={"SourceSansSemibold"}
          size={new UDim2(1, 0, 0, px(45))}
          layoutOrder={0}
        />

        {moveHistory
          .filter((_, i) => i % 2 === 0) // only white moves, since black moves will be displayed same place
          .map((move, minimizedIndex) => {
            const index = minimizedIndex * 2;
            const blackResponse = moveHistory[index + 1];
            return (
              <Frame
                layoutOrder={minimizedIndex}
                size={new UDim2(1, 0, 0, px(35))}
                background={minimizedIndex % 2 === 0 ? "#403E39" : "#282723"}
                key={minimizedIndex}
                backgroundTransparency={0.5}
                padding={px(5)}
                paddingLeft={px(10)}
              >
                <ListLayout
                  direction={"Horizontal"}
                  verticalAlign={"Center"}
                  horizontalAlign={"Left"}
                  order={"LayoutOrder"}
                  padding={px(15)}
                />
                <Text
                  text={`${minimizedIndex + 1}.`}
                  textColor={new Color3(0.6, 0.6, 0.6)}
                  textSize={px(20)}
                  font={"SourceSansSemibold"}
                  textAlign={"Left"}
                  size={new UDim2(0.05, 0, 1, 0)}
                  noBackground
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
                  Font={"SourceSansSemibold"}
                  Size={new UDim2(0, 0, 1, 0)}
                  AutomaticSize={"X"}
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
                    Font={"SourceSansSemibold"}
                    Size={new UDim2(0, 0, 1, 0)}
                    AutomaticSize={"X"}
                    BackgroundTransparency={1}
                    Event={{
                      MouseButton1Click: () => onRewind(index + 1),
                    }}
                  />
                )}
              </Frame>
            );
          })}
      </ScrollingFrame>

      <Button
        title={"Resign"}
        image={"rbxassetid://10723375890"}
        callback={() => gameplay?.resign()}
      />
      <Button
        title={"Draw"}
        image={"rbxassetid://13738539975"}
        callback={() => gameplay?.draw()}
      />
    </CanvasGroup>
  );
}
