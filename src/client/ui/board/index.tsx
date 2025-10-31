import React, { Binding, useEffect, useRef, useState } from "@rbxts/react";
import {
  Color,
  FILES,
  RANKS,
  IsSquareBlack,
  Piece as PieceType,
} from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Wood, IconPack } from "./images";
import { Frame, Text } from "@rbxts/better-react-components";
import { default as GetLegalMoves } from "shared/engine/legalMoves";
import { Image } from "../image";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { BitBoard } from "shared/engine/bitboard";
import { GetBestMoveAPI } from "shared/engine/api";

const DISPLAY_SQUARE_LABELS = true;
export const FLIPPED = false;

export interface PieceProps {
  pos: Binding<UDim2> | UDim2;
  location: number;
  iconPack: IconPack;
  playingAs: Color;
  piece: [PieceType, Color];
}

export function Piece(props: PieceProps) {
  const board = useAtom(Atoms.Board);
  const holdingPiece = useAtom(Atoms.HoldingPiece);

  const [offsetY, offsetYMotion] = useMotion(0);

  /* Block data */
  const image = props.piece
    ? props.iconPack[props.piece[1]][props.piece[0]]
    : undefined;
  const isMyPiece =
    props.playingAs === (props.piece ? props.piece[1] : undefined);

  /* Events */
  const onDown = () => {
    if (!props.location || !props.piece) return;

    if (holdingPiece === props.location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (props.piece[0] !== 0 && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(props.location);
      Atoms.PossibleMoves(GetLegalMoves(board, props.location));
    }
  };

  return (
    <Frame
      position={props.pos}
      size={new UDim2(1 / 8, 0, 1 / 8, 0)}
      noBackground
      zIndex={holdingPiece === props.location ? 100 : 3}
    >
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        Text={""}
        BackgroundTransparency={1}
        ZIndex={1}
        Event={{
          MouseEnter: () => {
            offsetYMotion.spring(isMyPiece ? -10 : 0);
          },
          MouseLeave: () => {
            offsetYMotion.spring(0);
          },
          MouseButton1Down: onDown,
        }}
      />
      {image ? (
        <Image
          image={image}
          position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
          size={new UDim2(1, 0, 1, 0)}
          outlinePrecision={30}
          outlineThickness={6}
          outlineStartAngle={40}
          outlineColor={new Color3(0.35, 0.35, 0.35)}
          zIndex={holdingPiece === props.location ? 100 : 3}
        />
      ) : undefined}
    </Frame>
  );
}
export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const iconPack = Wood;

  const movePieceInternal = (from: number, to: number) => {
    BitBoard.movePiece(board, from, to);
    BitBoard.flipTurn(board);
    Atoms.Board(BitBoard.branch(board));
    Atoms.PossibleMoves([]);
  };
  const movePiece = (location: number) => {
    if (!possibleMoves.includes(location) || !holdingPiece) return;

    movePieceInternal(holdingPiece, location);

    const best = GetBestMoveAPI(board);
    if (!best) return;
    movePieceInternal(best[0], best[1]);
  };

  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      aspectRatio={1}
    >
      {/* Squares */}
      {FILES.map((letter, i) =>
        RANKS.map((number, j) => {
          const location = `${letter}${number}`;
          const index = BitBoard.getSquareIndex(i, j);
          const colored = IsSquareBlack(i, j);

          const boardJ = FLIPPED ? j : 7 - j;

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
                {DISPLAY_SQUARE_LABELS && (
                  <Text
                    textColor={!colored ? iconPack.filled : iconPack.unfilled}
                    textSize={24}
                    text={location}
                    font={"SourceSansBold"}
                    backgroundTransparency={1}
                    size={new UDim2(1, 0, 1, 0)}
                    verticalTextAlign="Bottom"
                    textAlign="Left"
                  />
                )}
              </Frame>

              {/* Hitbox */}
              {possibleMoves.includes(index) && (
                <Frame
                  key={`${location}-hit`}
                  position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                  size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                  noBackground
                  zIndex={10}
                >
                  <textbutton
                    Size={new UDim2(1, 0, 1, 0)}
                    Text={""}
                    BackgroundTransparency={1}
                    ZIndex={1}
                    Event={{
                      MouseButton1Down: () => movePiece(index),
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
      {BitBoard.getAllPieces(board).map(([loc, piece]) => {
        const [i, j] = [loc % 8, math.floor(loc / 8)];
        return (
          <Piece
            key={loc}
            pos={new UDim2(i / 8, 0, (FLIPPED ? j : 7 - j) / 8, 0)}
            iconPack={iconPack}
            playingAs={Color.white}
            location={loc}
            piece={piece}
          />
        );
      })}
    </Frame>
  );
}
