import React, { useState, useRef, useEffect } from "@rbxts/react";
import {
  Color,
  GetPieceValues,
  IsPromotion,
  Piece as PieceType,
  Square,
} from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import { Vector, Wood } from "./images";
import { Frame } from "@rbxts/better-react-components";
import { BitBoard } from "shared/engine/bitboard";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { ChessBoard, ChessBoardRef } from "./Board";
import { Explorer } from "./Explorer";
import { Player } from "./Player";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import { usePx } from "../hooks/usePx";
import Atoms from "../atoms";
import { RunService } from "@rbxts/services";
import { Move } from "shared/engine/move";

export default function Board() {
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const currentMove = useAtom(Atoms.CurrentMove);

  const px = usePx();
  const iconPack = Vector;

  const chessBoardRef = useRef<ChessBoardRef>(undefined);
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [promoting, setPromoting] = useState<Square>(-1);

  const gameplay = RunService.IsRunning()
    ? useFlameworkDependency<Gameplay>()
    : undefined;
  const takenPieces = gameplay?.useTakenPieces() ?? [];

  const board = gameplay?.useBoard() ?? BitBoard.create();
  const moveHistory = gameplay?.useMoveHistory() ?? [];
  const playingAs = gameplay?.usePlayingAs() ?? Color.white;
  const activeGame = gameplay?.useActiveGame() ?? {
    color: Color.white,
  };

  gameplay?.setChessBoard(chessBoardRef);
  gameplay?.setEvaluationBar(evalBarRef);

  /* Handlers */
  const onMove = (location: number) => {
    if (
      !possibleMoves.find((v) => Move.getTo(v) === location) ||
      holdingPiece === undefined ||
      board.side_to_move !== playingAs
    ) {
      return;
    }

    const piece = BitBoard.get_piece(board, holdingPiece);
    if (!piece) return;

    if (IsPromotion(location, ...piece)) {
      setPromoting(location);
      return;
    }

    gameplay?.movePiece([holdingPiece, location, undefined], true);
  };
  const onPromote = (piece?: PieceType) => {
    if (!holdingPiece || !piece) {
      setPromoting(-1);
      return;
    }
    gameplay?.movePiece([holdingPiece, promoting, piece], true);
    setPromoting(-1);
  };
  const onRewind = (moveIndex: number) => {
    const prevBoard =
      moveIndex === 0 ? BitBoard.create() : moveHistory[moveIndex - 1].state;
    chessBoardRef.current?.setBoard(prevBoard);
    task.wait();
    /* TODO: Check SFX does not play in explorer, since moves are not simulated then attacked squares cannot be calculated. */
    gameplay?.movePiece(
      [
        moveHistory[moveIndex].from,
        moveHistory[moveIndex].to,
        moveHistory[moveIndex].promotion,
      ],
      false,
      BitBoard.get_piece(prevBoard, moveHistory[moveIndex].from)![1],
      prevBoard, // temporary!
    );
    Atoms.CurrentMove(moveIndex);
    Atoms.PossibleMoves([]);
  };

  /* Events */
  useEffect(() => gameplay?.newGame(), []);
  useEffect(() => setPromoting(-1), [board]);

  const isPlayer1Turn =
    moveHistory.size() === 0
      ? activeGame.color === Color.white
      : currentMove % 2 !== activeGame.color;
  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
    >
      <EvaluationBar
        ref={evalBarRef}
        size={new UDim2(0, px(40), 0.975 * 0.85, 0)}
        position={new UDim2(0.05, 0, 0.5, 0)}
        analysis={activeGame.analysis!}
      />
      <Frame
        size={new UDim2(1, 0, 0.975, 0)}
        position={new UDim2(0.35, 0, 0.5, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        aspectRatio={1}
        zIndex={2}
        noBackground
      >
        <uilistlayout
          VerticalAlignment={"Center"}
          HorizontalAlignment={"Center"}
          FillDirection={"Vertical"}
          Padding={new UDim(0, px(10))}
          SortOrder={"LayoutOrder"}
        />

        {/* Player component handles layout with the layoutOrder being either 0 or 2 */}
        <Player
          userId={activeGame.player2 ?? 0}
          flag={"🇺🇸"}
          rating={activeGame.player2elo ?? 0}
          time={activeGame.player2time ?? 0}
          color={1 - (activeGame.color ?? Color.white)}
          valueDifference={
            GetPieceValues(takenPieces[currentMove]?.[1] ?? []) -
            GetPieceValues(takenPieces[currentMove]?.[0] ?? [])
          }
          piecesTaken={takenPieces[currentMove]?.[1] ?? []}
          iconPack={iconPack}
          isMyTurn={!isPlayer1Turn}
        />
        <Player
          userId={activeGame.player1 ?? 0}
          flag={"🇺🇸"}
          rating={activeGame.player1elo ?? 0}
          time={activeGame.player1time ?? 0}
          color={activeGame.color ?? Color.white}
          valueDifference={
            GetPieceValues(takenPieces[currentMove]?.[0] ?? []) -
            GetPieceValues(takenPieces[currentMove]?.[1] ?? [])
          }
          piecesTaken={takenPieces[currentMove]?.[0] ?? []}
          iconPack={iconPack}
          isMyTurn={isPlayer1Turn}
        />
        <ChessBoard
          ref={chessBoardRef}
          iconPack={iconPack}
          playingAs={playingAs}
          onPromote={onPromote}
          onMove={onMove}
          promoting={promoting}
          locked={
            //gameId === "" ||
            activeGame.analysis !== "" ||
            /* if the move is not empty, then if the currentMove is not
          the last move  (rewinding) */
            (moveHistory.size() === 0
              ? false
              : currentMove !== moveHistory.size() - 1)
          }
          size={new UDim2(0.85, 0, 0.85, 0)}
        />
      </Frame>

      <Explorer
        opening={activeGame.opening ?? "No game"}
        currentMove={currentMove}
        position={new UDim2(0.85, 0, 0.5, 0)}
        onRewind={onRewind}
      />
    </Frame>
  );
}
