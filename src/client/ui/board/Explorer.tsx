import {
  Frame,
  ListLayout,
  ScrollingFrame,
  Text,
} from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { usePx } from "../usePx";

export interface ExplorerProps {
  opening: string;
  currentMove: number;
  onRewind: (index: number) => void;
}
export function Explorer({ opening, currentMove, onRewind }: ExplorerProps) {
  const pgn = useAtom(Atoms.PGN);
  const px = usePx();

  return (
    <ScrollingFrame
      size={new UDim2(0.25, 0, 0.975, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
      canvasSize={new UDim2(0.25, 0, 0, 0)}
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

      {/* Explorer */}
      {pgn
        .filter((_, i) => i % 2 === 0) // only white moves, since black moves will be displayed same place
        .map((move, minimizedIndex) => {
          const index = minimizedIndex * 2;
          const blackResponse = pgn[index + 1];
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
                Text={move.notation}
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
                  Text={blackResponse.notation}
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
  );
}
