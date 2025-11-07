import { Frame, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import {
  Color,
  FILES,
  IsSquareBlack,
  RANKS,
  Piece as PieceType,
  Square,
} from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { usePx } from "../usePx";
import { IconPack } from "./images";
import { Promotion } from "./Promotion";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Piece } from "./Piece";

export default function ChessBoard({
  iconPack,
  playingAs,
  onPromote,
  onMove,
  promoting,
  locked,
  pieces,
  size,
}: {
  iconPack: IconPack;
  playingAs: Color;
  promoting: Square;
  onMove: (loc: Square) => void;
  onPromote: (piece?: PieceType) => void;
  locked: boolean;
  pieces: [number, [PieceType, Color]][];
  size: UDim2;
}) {
  const possibleMoves = useAtom(Atoms.PossibleMoves);

  const px = usePx();
  return (
    <Frame size={size} aspectRatio={1}>
      {/* Squares */}
      {FILES.map((letter, i) =>
        RANKS.map((number, j) => {
          const location = `${letter}${number}`;
          const index = BitBoard.getSquareIndex(i, j);
          const colored = IsSquareBlack(i, j);

          const boardJ = playingAs ? j : 7 - j;

          return (
            <>
              {/* Square background */}
              <Frame
                key={`${location}-square`}
                position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                background={colored ? iconPack.filled : iconPack.unfilled}
                zIndex={1}
              >
                {boardJ === 7 && (
                  <Text
                    textColor={!colored ? iconPack.filled : iconPack.unfilled}
                    textSize={px(20)}
                    text={letter}
                    font={"SourceSansBold"}
                    backgroundTransparency={1}
                    padding={px(3)}
                    size={new UDim2(1, 0, 1, 0)}
                    verticalTextAlign="Bottom"
                    textAlign="Right"
                  />
                )}
                {i === 0 && (
                  <Text
                    textColor={!colored ? iconPack.filled : iconPack.unfilled}
                    textSize={px(20)}
                    padding={px(3)}
                    text={number}
                    font={"SourceSansBold"}
                    backgroundTransparency={1}
                    size={new UDim2(1, 0, 1, 0)}
                    verticalTextAlign="Top"
                    textAlign="Left"
                  />
                )}
              </Frame>

              {/* Hitbox */}
              {possibleMoves.find((v) => v[0] === index) && (
                <Frame
                  key={`${location}-hit`}
                  position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                  size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                  noBackground
                  zIndex={1000}
                >
                  <textbutton
                    Size={new UDim2(1, 0, 1, 0)}
                    Text={""}
                    BackgroundTransparency={1}
                    ZIndex={1}
                    Event={{
                      MouseButton1Down: () => onMove(index),
                    }}
                  />
                  <Frame
                    size={new UDim2(0.35, 0, 0.35, 0)}
                    position={new UDim2(0.5, 0, 0.5, 0)}
                    anchorPoint={new Vector2(0.5, 0.5)}
                    background={new Color3(0, 0, 0)}
                    backgroundTransparency={0.75}
                    cornerRadius={new UDim(0.5, 0)}
                    zIndex={5}
                  />
                </Frame>
              )}
            </>
          );
        }),
      )}

      {/* Pieces */}
      {pieces.map(([loc, piece], index) => {
        const pos = BitBoard.separateSquareIndex(loc);
        return (
          <Piece
            key={index}
            pos={pos}
            iconPack={iconPack}
            playingAs={playingAs}
            location={loc}
            piece={piece}
            locked={locked}
          />
        );
      })}

      {/* Promotion popup */}
      {promoting > 0 ? (
        <Promotion
          color={playingAs}
          iconPack={iconPack}
          location={promoting}
          onPromote={onPromote}
        />
      ) : undefined}
    </Frame>
  );
}
