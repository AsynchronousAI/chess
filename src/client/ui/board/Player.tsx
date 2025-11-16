import { useEffect, useState } from "@rbxts/react";
import { Color, Piece, PieceValues } from "shared/board";
import { Players } from "@rbxts/services";
import { Frame, Image, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { IconPack, Vector } from "./images";
import { Object } from "@rbxts/luau-polyfill";
import { useInterval } from "@rbxts/pretty-react-hooks";
import { usePx } from "../hooks/usePx";
import { usePlayer } from "../hooks/usePlayer";

const formatTime = (seconds: number) => {
  /* incase the visual goes negative, in the time
  that server needs to inform us of a timeout */
  seconds = math.max(seconds, 0);

  if (seconds > 60) {
    /* standard x:xx */
    seconds = math.floor(seconds);
    const minutes = math.floor(seconds / 60);
    const remaining = seconds % 60;
    const padded = remaining < 10 ? `0${remaining}` : `${remaining}`;
    return `${minutes}:${padded}`;
  } else {
    /* rushed mode! 0:xx.x */
    const formatted = string.format("%.1f", seconds);
    const padded = seconds < 10 ? `0${formatted}` : `${formatted}`;
    return `0:${padded}`;
  }
};
function repeating<T extends defined>(
  n: number,
  render: (i: number) => T,
): T[] {
  const out: T[] = [];
  for (let i = 0; i < n; i++) out.push(render(i));
  return out;
}
const clocks = [
  "rbxassetid://10709799535",
  "rbxassetid://10709803876",
  "rbxassetid://10709803989",
  "rbxassetid://10709804164",
  "rbxassetid://10709804291",
  "rbxassetid://10709804435",
  "rbxassetid://10709804599",
  "rbxassetid://10709804784",
  "rbxassetid://10709804996",
  "rbxassetid://10709799718",
  "rbxassetid://10709799818",
  "rbxassetid://10709799962",
];

export function Player({
  userId,
  flag,
  rating,
  time,
  color,
  valueDifference,
  piecesTaken,
  iconPack,
  isMyTurn,
}: {
  userId: number;
  flag: string;
  rating: number;
  time: number;
  color: Color;
  valueDifference: number;
  piecesTaken: Piece[];
  iconPack: IconPack;
  isMyTurn: boolean;
}) {
  const px = usePx();
  const [name, thumbnail] = usePlayer(userId);
  const [clockIndex, setClockIndex] = useState(0);

  useInterval(() => {
    setClockIndex((c) => (c + 1) % clocks.size());
  }, 0.5);

  /* ["a", "a", "b"] into {"a": 2, "b": 1} */
  const groupedPieces = Object.entries(
    piecesTaken.reduce<Record<string, number>>((acc, val) => {
      acc[val] = (acc[val] || 0) + 1;
      return acc;
    }, {}),
  ) as unknown as [Piece, number][];

  return (
    <Frame
      size={new UDim2(0.85, 0, 0.05, 0)}
      noBackground
      layoutOrder={
        userId === Players.LocalPlayer?.UserId ? 2 : 0
      } /* align to top or bottom */
      visible={userId !== 0}
    >
      {/* Player details */}
      <Image
        background={"#403E39"}
        cornerRadius={px(2)}
        visible={thumbnail !== ""}
        image={thumbnail}
        size={new UDim2(1, 0, 1, 0)}
        aspectRatio={1}
      />
      <Text
        noBackground
        richText
        text={`<b>${name}</b> <font color="rgb(128,128,128)">(${rating})</font> ${flag}`}
        size={new UDim2(0.85, 0, 0.45, 0)}
        position={new UDim2(0.085, 0, 0, 0)}
        textSize={px(18)}
        textAlign={"Left"}
        paddingLeft={px(2)}
        paddingTop={px(15)}
        paddingBottom={px(15)}
        textColor={new Color3(1, 1, 1)}
        font={"SourceSans"}
      />

      {/* Pieces */}
      <Frame
        size={new UDim2(1, 0, 0.5, 0)}
        noBackground
        position={new UDim2(0.085, 0, 0.55, 0)}
      >
        <uilistlayout
          VerticalAlignment={"Center"}
          HorizontalAlignment={"Left"}
          FillDirection={"Horizontal"}
          Padding={new UDim(0, -px(3))}
          SortOrder={"LayoutOrder"}
        />

        {groupedPieces.map(([piece, count]) => {
          return (
            <Frame
              key={piece}
              size={new UDim2(0, 0, 1, 0)}
              automaticSize={"X"}
              noBackground
              layoutOrder={PieceValues[piece]}
              position={new UDim2(0.085, 0, 0.55, 0)}
            >
              <uilistlayout
                VerticalAlignment={"Center"}
                HorizontalAlignment={"Left"}
                FillDirection={"Horizontal"}
                Padding={
                  new UDim(0, -px(piece === Piece.pawn ? 13 : 10))
                } /* pawns need to be closer */
                SortOrder={"LayoutOrder"}
              />
              {repeating(count, () => (
                <Image
                  key={count}
                  image={iconPack[(1 - color) as Color][piece]}
                  noBackground
                  size={new UDim2(0, px(20), 0, px(20))}
                  aspectRatio={1}
                  layoutOrder={PieceValues[piece]}
                />
              ))}
            </Frame>
          );
        })}

        {valueDifference > 0 ? (
          <Text
            text={`+${valueDifference}`}
            size={new UDim2(0.05, 0, 1, 0)}
            textSize={px(17)}
            layoutOrder={100}
            noBackground
            textColor={new Color3(0.65, 0.65, 0.65)}
            font={"SourceSansSemibold"}
          />
        ) : undefined}
      </Frame>

      {/* Clock */}
      <Text
        size={new UDim2(0.2, 0, 1, 0)}
        position={new UDim2(0.8, 0, 0, 0)}
        text={formatTime(time)}
        background={
          time < 60
            ? "#f24349"
            : color === Color.white
              ? new Color3(1, 1, 1)
              : "#403E39"
        }
        textSize={px(25)}
        textAlign={"Right"}
        verticalTextAlign={"Center"}
        paddingRight={px(10)}
        textColor={
          time < 60
            ? new Color3(1, 1, 1)
            : color === Color.white
              ? "#403E39"
              : new Color3(1, 1, 1)
        }
        font={"SourceSansSemibold"}
        backgroundTransparency={isMyTurn ? 0 : 0.5}
        overrideRoblox={{ TextTransparency: isMyTurn ? 0 : 0.5 }}
        cornerRadius={px(2)}
      >
        <Image
          noBackground
          size={new UDim2(0.55, 0, 0.55, 0)}
          aspectRatio={1}
          image={clocks[clockIndex]}
          imageColor={
            time < 60
              ? new Color3(1, 1, 1)
              : color === Color.white
                ? "#403E39"
                : new Color3(1, 1, 1)
          }
          anchorPoint={new Vector2(0, 0.5)}
          position={new UDim2(0.1, 0, 0.5, 0)}
          visible={isMyTurn}
        />
      </Text>
    </Frame>
  );
}
