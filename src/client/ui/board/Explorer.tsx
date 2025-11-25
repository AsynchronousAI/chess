import {
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
import { useMotion } from "@rbxts/pretty-react-hooks";
import { RunService } from "@rbxts/services";
import { PGN } from "shared/engine/pgn";

export interface ExplorerProps {
  opening: string;
  currentMove: number;
  onRewind: (index: number, backwards?: boolean) => void;
}
function ExplorerButton({
  title,
  image,
  callback,
}: {
  title: string;
  image: string;
  callback: () => void;
}) {
  const px = usePx();
  const [scale, scaleMotion] = useMotion(1);
  return (
    <Frame
      size={scale.map((x) => new UDim2(0.15 * x, 0, 0.15, 0))}
      aspectRatio={scale}
      cornerRadius={px(2)}
      background={"#403E39"}
      visible={true}
    >
      <Image
        size={new UDim2(0.65, 0, 0.65, 0)}
        anchorPoint={new Vector2(0, 0.5)}
        position={new UDim2(0, px(10), 0.5, 0)}
        imageColor={new Color3(0.75, 0.75, 0.75)}
        noBackground
        aspectRatio={1}
        image={image}
      />
      <Text
        text={title}
        size={new UDim2(1, 0, 1, 0)}
        font={"SourceSansBold"}
        textColor={new Color3(0.75, 0.75, 0.75)}
        noBackground
        overrideRoblox={{
          TextTransparency: scale.map((x) => math.map(x, 1, 3, 1, 0)),
        }}
        textSize={px(26)}
        padding={px(5)}
        paddingLeft={px(20)}
      />
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        BackgroundTransparency={1}
        Text=""
        Event={{
          MouseButton1Click: () => callback(),
          MouseEnter: () => scaleMotion.spring(3),
          MouseLeave: () => scaleMotion.spring(1),
        }}
      />
    </Frame>
  );
}
export function Explorer({ opening, currentMove, onRewind }: ExplorerProps) {
  const gameplay = RunService.IsRunning()
    ? useFlameworkDependency<Gameplay>()
    : undefined;
  const pgn = gameplay?.usePGN() ?? PGN.create();
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

      <ExplorerButton
        title={"Resign"}
        image={"rbxassetid://10723375890"}
        callback={() => gameplay?.resign()}
      />
      <ExplorerButton
        title={"Draw"}
        image={"rbxassetid://13738539975"}
        callback={() => gameplay?.draw()}
      />
    </CanvasGroup>
  );
}
