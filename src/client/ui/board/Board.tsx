import { Frame, Text } from "@rbxts/better-react-components";
import React, { forwardRef, useImperativeHandle, useState } from "@rbxts/react";
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
import { HttpService } from "@rbxts/services";

export interface ChessBoardProps {
  iconPack: IconPack;
  playingAs: Color;
  promoting: Square;
  onMove: (loc: Square) => void;
  onPromote: (piece?: PieceType) => void;
  locked: boolean;
  size: UDim2;
}
export interface ChessBoardRef {
  setBoard: (board: BitBoard) => void;
  animateBoard: (
    from: number,
    to: number,
    as?: PieceType,
    closure?: [Square, Square?], // special moves such as en passant and castling use a closure
  ) => void;
}
export const ChessBoard = forwardRef<ChessBoardRef, ChessBoardProps>(
  (props, ref) => {
    const possibleMoves = useAtom(Atoms.PossibleMoves);
    const [pieces, setPieces] = useState<
      [
        number /* location */,
        [PieceType, Color] /* piece information */,
        string /* key, used for animations */,
      ][]
    >([]);

    const px = usePx();

    useImperativeHandle(ref, () => ({
      setBoard: (board) => {
        setPieces(
          BitBoard.getAllPieces(board).map(([location, piece]) => [
            location,
            piece,
            HttpService.GenerateGUID(),
          ]),
        );
      },
      animateBoard: (from, to, as, closure) => {
        setPieces((currentPieces) => {
          for (const piece of currentPieces) {
            if (piece[0] === from) {
              piece[0] = to;
              if (as) piece[1][0] = as;
            } else if (piece[0] === to) {
              piece[1][0] = PieceType.none;
            } else if (closure !== undefined && piece[0] === closure[0]) {
              if (closure[1]) piece[0] = closure[1];
              else piece[1][0] = PieceType.none;
            }
          }
          return currentPieces;
        });
      },
    }));

    return (
      <Frame size={props.size} aspectRatio={1}>
        {/* Squares */}
        {FILES.map((letter, i) =>
          RANKS.map((number, j) => {
            const location = `${letter}${number}`;
            const index = BitBoard.getSquareIndex(i, j);
            const colored = IsSquareBlack(i, j);

            const boardJ = props.playingAs ? j : 7 - j;

            return (
              <>
                {/* Square background */}
                <Frame
                  key={`${location}-square`}
                  position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                  size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                  background={
                    colored ? props.iconPack.filled : props.iconPack.unfilled
                  }
                  zIndex={1}
                >
                  {boardJ === 7 && (
                    <Text
                      textColor={
                        !colored
                          ? props.iconPack.filled
                          : props.iconPack.unfilled
                      }
                      textSize={px(20)}
                      text={props.playingAs === 1 ? FILES[7 - i] : FILES[i]}
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
                      textColor={
                        !colored
                          ? props.iconPack.filled
                          : props.iconPack.unfilled
                      }
                      textSize={px(20)}
                      padding={px(3)}
                      text={RANKS[boardJ]}
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
                        MouseButton1Down: () => props.onMove(index),
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
        {pieces.map(([loc, piece, key]) => {
          const pos = BitBoard.separateSquareIndex(loc);
          return (
            <Piece
              key={key}
              pos={pos}
              iconPack={props.iconPack}
              playingAs={props.playingAs}
              location={loc}
              piece={piece}
              locked={props.locked}
            />
          );
        })}

        {/* Promotion popup */}
        {props.promoting > 0 ? (
          <Promotion
            color={props.playingAs}
            iconPack={props.iconPack}
            location={props.promoting}
            onPromote={props.onPromote}
          />
        ) : undefined}
      </Frame>
    );
  },
);
