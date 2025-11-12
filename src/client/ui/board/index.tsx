import React, { useState, useRef, useEffect } from "@rbxts/react";
import {
  Color,
  GetPieceValues,
  Piece as PieceType,
  Square,
} from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Vector, Wood } from "./images";
import { Frame } from "@rbxts/better-react-components";
import { BitBoard } from "shared/engine/bitboard";
import { usePx } from "../usePx";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { Events } from "client/network";
import { ChessBoard, ChessBoardRef } from "./Board";
import { DefaultBoard, FEN } from "shared/engine/fen";
import { Explorer } from "./Explorer";
import { Player } from "./Player";
import { SoundEffects } from "./sfx";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";

export default function Board() {
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const currentMove = useAtom(Atoms.CurrentMove);

  const px = usePx();
  const iconPack = Wood;

  const chessBoardRef = useRef<ChessBoardRef>(undefined);
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [promoting, setPromoting] = useState<Square>(-1);

  const gameplay = useFlameworkDependency<Gameplay>();
  const [player1taken, player2taken] = gameplay.useTakenPieces();

  const board = gameplay.useBoard();
  const pgn = gameplay.usePGN();
  const playingAs = gameplay.usePlayingAs();
  const activeGame = gameplay.useActiveGame();

  gameplay.setChessBoard(chessBoardRef);
  gameplay.setEvaluationBar(evalBarRef);

  /* Handlers */
  const onMove = (location: number) => {
    if (
      !possibleMoves.find((v) => v[0] === location) ||
      holdingPiece === undefined ||
      BitBoard.getTurn(board) !== playingAs
    ) {
      return;
    }

    const piece = BitBoard.getPiece(board, holdingPiece);
    if (
      piece[0] === PieceType.pawn &&
      (playingAs === Color.white ? location > 55 : location < 8)
    ) {
      setPromoting(location);
      return;
    }

    gameplay.movePiece(holdingPiece, location, true);
  };
  const onPromote = (piece?: PieceType) => {
    if (!holdingPiece || !piece) {
      setPromoting(-1);
      return;
    }
    gameplay.movePiece(holdingPiece, promoting, true, piece);
    setPromoting(-1);
  };
  const onRewind = (moveIndex: number, backwards = false) => {
    /* TODO: Special moves like castling & en passant animated when rewind */
    if (!backwards) {
      chessBoardRef.current?.setBoard(
        moveIndex === 0 ? DefaultBoard : pgn[moveIndex - 1].state,
      );
      task.wait();
      chessBoardRef.current?.animateBoard(
        pgn[moveIndex].from,
        pgn[moveIndex].to,
        pgn[moveIndex].promotion
          ? [pgn[moveIndex].promotion, moveIndex % 2]
          : undefined,
      );
    } else {
      chessBoardRef.current?.setBoard(
        moveIndex === 0 ? DefaultBoard : pgn[moveIndex + 1].state,
      );
      task.wait();
      chessBoardRef.current?.animateBoard(
        pgn[moveIndex].to,
        pgn[moveIndex].from,
        pgn[moveIndex].promotion ? [PieceType.pawn, moveIndex % 2] : undefined,
      );
    }
    gameplay.playSFX(pgn[moveIndex].moveType as keyof typeof SoundEffects);
    Atoms.CurrentMove(moveIndex);
    Atoms.PossibleMoves([]);
  };

  /* Events */
  useEffect(() => gameplay.newGame(), []);

  const isPlayer1Turn =
    pgn.size() === 0
      ? activeGame.color === Color.white
      : currentMove % 2 !== activeGame.color;
  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      background={new Color3(0.1, 0.1, 0.1)}
    >
      <uilistlayout
        VerticalAlignment={"Center"}
        HorizontalAlignment={"Center"}
        FillDirection={"Horizontal"}
        Wraps
        Padding={new UDim(0, px(5))}
      />

      <EvaluationBar
        ref={evalBarRef}
        size={new UDim2(0.025, 0, 0.975 * 0.85, 0)}
        analysis={activeGame.analysis!}
      />
      <Frame size={new UDim2(1, 0, 0.975, 0)} aspectRatio={1} noBackground>
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
            GetPieceValues(player2taken) - GetPieceValues(player1taken)
          }
          piecesTaken={player2taken}
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
            GetPieceValues(player1taken) - GetPieceValues(player2taken)
          }
          piecesTaken={player1taken}
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
            /* if the PGN is not empty, then if the currentMove is not
          the last move  (rewinding) */
            (pgn.size() === 0 ? false : currentMove !== pgn.size() - 1)
          }
          size={new UDim2(0.85, 0, 0.85, 0)}
        />
      </Frame>

      <Explorer
        opening={activeGame.opening ?? "No game"}
        currentMove={currentMove}
        onRewind={onRewind}
      />
    </Frame>
  );
}
