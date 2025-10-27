import React, { useEffect, useRef, useState } from "@rbxts/react";

import { Image } from "../image";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Color, Piece as PieceType, Square } from "shared/board";
import { IconPack } from "./images";
import { useMotion } from "@rbxts/pretty-react-hooks";
import GetLegalMoves, { AnalyzeMates } from "shared/engine/legalMoves";
import { Frame } from "@rbxts/better-react-components";
import { FLIPPED } from "./square";
import { GetBestMove } from "shared/engine/bots";
import { BitBoard } from "shared/engine/bitboard";

export interface PieceProps {
  letter: string;
  number: string;
  i: number;
  j: number;
  iconPack: IconPack;
  playingAs: Color;
}
export function Piece(props: PieceProps) {
  const board = useAtom(Atoms.Board);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const possibleMoves = useAtom(Atoms.PossibleMoves);

  const containerRef = useRef<Frame>();

  const [offsetY, offsetYMotion] = useMotion(0);

  /* Block data */
  const location = [props.i, props.j] as Square;
  const pieceAtBoard = BitBoard.getPiece(board, location);
  const image = pieceAtBoard
    ? props.iconPack[pieceAtBoard[1]][pieceAtBoard[0]]
    : undefined;
  const isMyPiece =
    props.playingAs === (pieceAtBoard ? pieceAtBoard[1] : undefined);

  /* Other */
  const [canMoveHere, setCanMoveHere] = useState(false);
  useEffect(() => {
    if (!location) return;
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
    if (!location || !pieceAtBoard) return;

    if (holdingPiece === location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (pieceAtBoard[0] !== 0 && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(location);
      Atoms.PossibleMoves(GetLegalMoves(board, location));
    } else if (canMoveHere && holdingPiece) {
      // move
      Atoms.Board((currentBoard) => {
        BitBoard.movePiece(currentBoard, holdingPiece, location);
        BitBoard.flipTurn(currentBoard);
        Atoms.PGN((pgn) =>
          pgn.move(currentBoard, location, AnalyzeMates(currentBoard)),
        );
        return BitBoard.branch(currentBoard);
      });
      Atoms.PossibleMoves([]);

      Atoms.Board((currentBoard) => {
        const best = GetBestMove(currentBoard);
        if (!best) return currentBoard;
        BitBoard.movePiece(currentBoard, best[0], best[1]);
        BitBoard.flipTurn(currentBoard);
        Atoms.PGN((pgn) =>
          pgn.move(currentBoard, best[1], AnalyzeMates(currentBoard)),
        );
        return BitBoard.branch(currentBoard);
      });
    }
  };
  const onLeave = () => {
    offsetYMotion.spring(0);
  };

  return (
    <Frame
      ref={containerRef}
      key={`${props.letter}${props.number}`}
      position={
        new UDim2(
          props.i * (1 / 8),
          0,
          (FLIPPED ? props.j : 7 - props.j) * (1 / 8),
          0,
        )
      }
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
