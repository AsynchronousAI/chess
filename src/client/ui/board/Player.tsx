import { useEffect, useState } from "@rbxts/react";
import { Color, Piece, PieceValues } from "shared/board";
import { Players } from "@rbxts/services";
import React from "@rbxts/react";
import { IconPack, Vector } from "./images";
import { Object } from "@rbxts/luau-polyfill";
import { useInterval } from "@rbxts/pretty-react-hooks";
import { usePx } from "../hooks/usePx";
import { usePlayer } from "../hooks/usePlayer";
import Atoms from "../atoms";

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
    <frame
      Size={new UDim2(0.85, 0, 0.05, 0)}
      BackgroundTransparency={1}
      BorderSizePixel={0}
      LayoutOrder={
        userId === Players.LocalPlayer?.UserId ? 2 : 0
      } /* align to top or bottom */
      Visible={userId !== 0}
    >
      {/* Player details */}
      <imagelabel
        BackgroundColor3={Color3.fromHex("#403E39")}
        Visible={thumbnail !== ""}
        Image={thumbnail}
        Size={new UDim2(1, 0, 1, 0)}
        BorderSizePixel={0}
      >
        <uiaspectratioconstraint AspectRatio={1} />
        <uicorner CornerRadius={new UDim(0, px(2))} />
      </imagelabel>
      <textlabel
        BackgroundTransparency={1}
        RichText={true}
        Text={`<b>${name}</b> <font color="rgb(128,128,128)">(${rating})</font> ${flag}`}
        Size={new UDim2(0.85, 0, 0.45, 0)}
        Position={new UDim2(0.085, 0, 0, 0)}
        TextSize={px(18)}
        TextXAlignment={Enum.TextXAlignment.Left}
        TextColor3={new Color3(1, 1, 1)}
        Font={Enum.Font.SourceSans}
      >
        <uipadding
          PaddingLeft={new UDim(0, px(2))}
          PaddingTop={new UDim(0, px(15))}
          PaddingBottom={new UDim(0, px(15))}
        />
      </textlabel>

      {/* Pieces */}
      <frame
        Size={new UDim2(1, 0, 0.5, 0)}
        BackgroundTransparency={1}
        BorderSizePixel={0}
        Position={new UDim2(0.085, 0, 0.55, 0)}
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
            <frame
              key={piece}
              Size={new UDim2(0, 0, 1, 0)}
              AutomaticSize={Enum.AutomaticSize.X}
              BackgroundTransparency={1}
              BorderSizePixel={0}
              LayoutOrder={PieceValues[piece]}
              Position={new UDim2(0.085, 0, 0.55, 0)}
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
                <imagelabel
                  key={count}
                  Image={iconPack[(1 - color) as Color][piece]}
                  BackgroundTransparency={1}
                  Size={new UDim2(0, px(20), 0, px(20))}
                  LayoutOrder={PieceValues[piece]}
                >
                  <uiaspectratioconstraint AspectRatio={1} />
                </imagelabel>
              ))}
            </frame>
          );
        })}

        {valueDifference > 0 ? (
          <textlabel
            Text={`+${valueDifference}`}
            Size={new UDim2(0.05, 0, 1, 0)}
            TextSize={px(17)}
            LayoutOrder={100}
            BackgroundTransparency={1}
            TextColor3={new Color3(0.65, 0.65, 0.65)}
            Font={Enum.Font.SourceSansSemibold}
          />
        ) : undefined}
      </frame>

      {/* Clock */}
      <textlabel
        Visible={time >= 0}
        Size={new UDim2(0.2, 0, 1, 0)}
        Position={new UDim2(0.8, 0, 0, 0)}
        Text={formatTime(time)}
        BackgroundColor3={
          time < 60
            ? Color3.fromHex("#f24349")
            : color === Color.white
              ? new Color3(1, 1, 1)
              : Color3.fromHex("#403E39")
        }
        TextSize={px(25)}
        TextXAlignment={Enum.TextXAlignment.Right}
        TextYAlignment={Enum.TextYAlignment.Center}
        TextColor3={
          time < 60
            ? new Color3(1, 1, 1)
            : color === Color.white
              ? Color3.fromHex("#403E39")
              : new Color3(1, 1, 1)
        }
        Font={Enum.Font.SourceSansSemibold}
        BackgroundTransparency={isMyTurn ? 0 : 0.5}
        TextTransparency={isMyTurn ? 0 : 0.5}
        BorderSizePixel={0}
      >
        <uipadding PaddingRight={new UDim(0, px(10))} />
        <uicorner CornerRadius={new UDim(0, px(2))} />
        <imagelabel
          BackgroundTransparency={1}
          Size={new UDim2(0.55, 0, 0.55, 0)}
          Image={clocks[clockIndex]}
          ImageColor3={
            time < 60
              ? new Color3(1, 1, 1)
              : color === Color.white
                ? Color3.fromHex("#403E39")
                : new Color3(1, 1, 1)
          }
          AnchorPoint={new Vector2(0, 0.5)}
          Position={new UDim2(0.1, 0, 0.5, 0)}
          Visible={isMyTurn}
        >
          <uiaspectratioconstraint AspectRatio={1} />
        </imagelabel>
      </textlabel>

      {/* Button */}
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        TextTransparency={1}
        BackgroundTransparency={1}
        Event={{
          MouseButton1Click: () => Atoms.ViewingPlayer(userId),
        }}
      />
    </frame>
  );
}
