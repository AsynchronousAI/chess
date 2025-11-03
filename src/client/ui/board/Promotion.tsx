import React, { Binding } from "@rbxts/react";
import { Color, Piece as PieceType } from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { CanvasGroup, Frame, ListLayout } from "@rbxts/better-react-components";
import { Image } from "../image";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "../usePx";
import { Motion } from "@rbxts/ripple";
import { PromotionProps, generatePosition, FLIPPED } from "./shared";
import { BitBoard } from "shared/engine/bitboard";

export function Promotion({
  location,
  color,
  iconPack,
  onPromote,
}: PromotionProps) {
  const px = usePx();
  const holdingPiece = useAtom(Atoms.HoldingPiece);

  const pieces = [
    PieceType.bishop,
    PieceType.rook,
    PieceType.knight,
    PieceType.queen,
  ];
  const motions = pieces.map(() => [...useMotion(0)]) as [
    Binding<number>,
    Motion<number>,
  ][];

  const pos = BitBoard.separateSquareIndex(location);

  return (
    <CanvasGroup
      position={generatePosition(pos).add(
        color === Color.white && !FLIPPED
          ? new UDim2()
          : new UDim2(0, 0, -0.435, 0),
      )}
      size={new UDim2(1 / 8, 0, 4.5 / 8, 0)}
      zIndex={1000}
      background={new Color3(1, 1, 1)}
      cornerRadius={px(4)}
    >
      <ListLayout
        verticalAlign={"Top"}
        horizontalAlign={"Center"}
        direction={"Vertical"}
        order={"LayoutOrder"}
        padding={px(5)}
      />

      {/* Close */}
      <textbutton
        Font={"ArialBold"}
        TextSize={px(18)}
        Size={new UDim2(1, 0, 1 / 9, 0)}
        Text="X"
        TextColor3={new Color3(0.35, 0.35, 0.35)}
        BackgroundColor3={new Color3(0.95, 0.95, 0.95)}
        LayoutOrder={0}
        AutoButtonColor={false}
        Event={{
          MouseButton1Click: () => onPromote(undefined),
        }}
      >
        <uistroke
          Thickness={px(1)}
          Color={new Color3(0.85, 0.85, 0.85)}
          ApplyStrokeMode={"Border"}
        />
      </textbutton>

      {/* Options */}
      {pieces.map((piece, index) => {
        const [offsetY, offsetYMotion] = motions[index];
        return (
          <Frame
            size={new UDim2(1, -px(7), 1, -px(7))}
            noBackground
            zIndex={holdingPiece === location ? 100 : 3}
            key={index}
            layoutOrder={index + 1}
          >
            <uiaspectratioconstraint AspectRatio={1} />
            <textbutton
              Size={new UDim2(1, 0, 1, 0)}
              Text={""}
              BackgroundTransparency={1}
              ZIndex={1}
              Event={{
                MouseEnter: () => offsetYMotion.spring(-10),
                MouseLeave: () => offsetYMotion.spring(0),
                MouseButton1Click: () => onPromote(piece),
              }}
            />
            <Image
              image={iconPack[color][piece]!}
              position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
              size={new UDim2(1, 0, 1, 0)}
              outlinePrecision={30}
              outlineThickness={px(4)}
              outlineStartAngle={40}
              outlineColor={new Color3(0.35, 0.35, 0.35)}
              zIndex={holdingPiece === location ? 100 : 3}
            />
          </Frame>
        );
      })}
    </CanvasGroup>
  );
}
