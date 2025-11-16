import {
  Button,
  CanvasGroup,
  Frame,
  Image,
  ListLayout,
  ScrollingFrame,
  Text,
} from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { usePx } from "../hooks/usePx";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";

export interface ExplorerProps {
  opening: string;
  currentMove: number;
  onRewind: (index: number, backwards?: boolean) => void;
}
export function Explorer({ opening, currentMove, onRewind }: ExplorerProps) {
  const gameplay = useFlameworkDependency<Gameplay>();
  const pgn = gameplay.usePGN();
  const px = usePx();

  return (
    <CanvasGroup
      size={new UDim2(0.25, 0, 0.975, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
      cornerRadius={px(2)}
    >
      <uilistlayout
        FillDirection={"Horizontal"}
        Wraps
        VerticalAlignment={"Top"}
        HorizontalAlignment={"Center"}
        Padding={new UDim(0, px(5))}
        SortOrder={"LayoutOrder"}
      />
      <ScrollingFrame
        layoutOrder={0}
        noBackground
        size={new UDim2(1, 0, 1, 0)}
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

      {[
        "rbxassetid://10734961526",
        "rbxassetid://10709768114",
        "rbxassetid://10709768347",
        "rbxassetid://10734961809",
      ].map((imageId, i) => (
        <Frame
          key={imageId}
          layoutOrder={i + 1}
          size={new UDim2(0.15, 0, 0.15, 0)}
          aspectRatio={1}
          cornerRadius={px(2)}
          background={"#403E39"}
          visible={false}
        >
          <Image
            size={new UDim2(0.75, 0, 0.75, 0)}
            anchorPoint={new Vector2(0.5, 0.5)}
            position={new UDim2(0.5, 0, 0.5, 0)}
            imageColor={new Color3(0.75, 0.75, 0.75)}
            noBackground
            image={imageId}
          />
          <textbutton
            Size={new UDim2(1, 0, 1, 0)}
            BackgroundTransparency={1}
            Text=""
            Event={{
              MouseButton1Click: () => {
                if (i === 0) {
                  /* first move */
                  onRewind(0);
                } else if (i === 1) {
                  /* one move back */
                  if (currentMove > 0) onRewind(currentMove - 1, true);
                } else if (i === 2) {
                  /* one move forward */
                  if (currentMove < pgn.size() - 1) onRewind(currentMove + 1);
                } else if (i === 3) {
                  /* last move */
                  onRewind(pgn.size() - 1);
                }
              },
            }}
          />
        </Frame>
      ))}
    </CanvasGroup>
  );
}
