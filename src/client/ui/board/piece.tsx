import React, { useEffect, useRef, useState } from "@rbxts/react";

import { Image } from "../image";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Color, Square } from "shared/board";
import { IconPack } from "./images";
import { useMotion } from "@rbxts/pretty-react-hooks";
import GetLegalMoves from "shared/engine/legalMoves";
import { Frame } from "@rbxts/better-react-components";
import { BitBoard } from "shared/engine/bitboard";

export interface PieceProps {
  letter: string;
  number: string;
  i: number;
  j: number;
  board: BitBoard;
  iconPack: IconPack;
  playingAs: Color;
}
export function Piece(props: PieceProps) {
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const containerRef = useRef<Frame>();
  const possibleMoves = useAtom(Atoms.PossibleMoves);

  const [offsetY, offsetYMotion] = useMotion(0);

  /* Block data */
  const location = [props.i, props.j] as Square;
  const pieceAtBoard = props.board.getPiece(props.i, props.j);
  const image = pieceAtBoard
    ? props.iconPack[pieceAtBoard[1]][pieceAtBoard[0]]
    : undefined;
  const isMyPiece = props.playingAs === pieceAtBoard[1];
  const boardJ = props.playingAs === 0 ? 7 - props.j : props.j;

  /* Other */
  const [canMoveHere, setCanMoveHere] = useState(false);
  useEffect(() => {
    for (const move of possibleMoves) {
      if (move[0] === location[0] && move[1] === location[1]) {
        setCanMoveHere(true);
        return;
      }
    }
    setCanMoveHere(false);
  }, [possibleMoves, location]);

  /* Events */
  const onHover = () => {
    offsetYMotion.spring(isMyPiece ? -10 : 0);
  };
  const onDown = async () => {
    if (holdingPiece === location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (pieceAtBoard[0] !== 0 && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(location);
      Atoms.PossibleMoves(
        GetLegalMoves(props.board, location, props.playingAs),
      );
    } else if (canMoveHere && holdingPiece) {
      // move
      Atoms.Board((currentBoard) => {
        currentBoard.movePiece(holdingPiece, location);
        return currentBoard;
      });
      Atoms.PossibleMoves([]);
      Atoms.PlayingAs(1 - props.playingAs);
    }
  };
  const onLeave = () => {
    offsetYMotion.spring(0);
  };

  return (
    <Frame
      ref={containerRef}
      key={`${props.letter}${props.number}`}
      position={new UDim2(props.i * (1 / 8), 0, boardJ * (1 / 8), 0)}
      size={new UDim2(1 / 8, 0, 1 / 8, 0)}
      noBackground
      zIndex={holdingPiece === location ? 100 : 3}
    >
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        Text={""}
        BackgroundTransparency={1}
        Event={{
          MouseEnter: onHover,
          MouseLeave: onLeave,
          MouseButton1Down: onDown,
        }}
      />
      {canMoveHere && (
        <Frame
          size={new UDim2(0.35, 0, 0.35, 0)}
          position={new UDim2(0.5, 0, 0.5, 0)}
          anchorPoint={new Vector2(0.5, 0.5)}
          background={new Color3(0, 0, 0)}
          backgroundTransparency={0.75}
          cornerRadius={new UDim(0.5, 0)}
        />
      )}
      {image ? (
        <Image
          image={image}
          position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
          size={new UDim2(1, 0, 1, 0)}
          outlinePrecision={30}
          outlineThickness={6}
          outlineStartAngle={40}
          outlineColor={new Color3(0.35, 0.35, 0.35)}
          zIndex={holdingPiece === location ? 100 : 3}
        />
      ) : undefined}
    </Frame>
  );
}
