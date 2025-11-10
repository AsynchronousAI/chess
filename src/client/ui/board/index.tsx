import React, { useState, useRef, useEffect, useMemo } from "@rbxts/react";
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
import {
  default as GetLegalMoves,
  IsSquareAttacked,
} from "shared/engine/legalMoves";
import { BitBoard } from "shared/engine/bitboard";
import { SoundEffects } from "./sfx";
import { SoundService } from "@rbxts/services";
import { usePx } from "../usePx";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { useEventListener, useInterval } from "@rbxts/pretty-react-hooks";
import { Events } from "client/network";
import { ChessBoard, ChessBoardRef } from "./Board";
import { PGN } from "shared/engine/pgn";
import { DefaultBoard, FEN } from "shared/engine/fen";
import { Game } from "server/services/gameplay";
import { Explorer } from "./Explorer";
import { Player } from "./Player";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const pgn = useAtom(Atoms.PGN);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const dragging = useAtom(Atoms.Dragging);
  const currentMove = useAtom(Atoms.CurrentMove);

  const px = usePx();
  const iconPack = Wood;

  const chessBoardRef = useRef<ChessBoardRef>(undefined);
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [promoting, setPromoting] = useState<Square>(-1);
  const [gameId, setGameId] = useState("");
  const [opening, setOpening] = useState("Starting game...");
  const [activeGame, setGame] = useState<Partial<Game>>({});

  const [player1taken, setPlayer1taken] = useState<PieceType[]>([]);
  const [player2taken, setPlayer2taken] = useState<PieceType[]>([]);

  /* Utils */
  const playSFX = (sfx: keyof typeof SoundEffects) => {
    const newAudio = new Instance("Sound", SoundService);
    newAudio.SoundId = SoundEffects[sfx];
    newAudio.Play();
    newAudio.Ended.Connect(() => newAudio.Destroy());
  };
  const movePiece = (
    from: number,
    to: number,
    myMove: boolean, // this will use cached move data & let server know if it is on
    as?: PieceType,
    pushPGN: boolean = true,
    color: Color = myMove ? playingAs : 1 - playingAs,
  ) => {
    /* Locate the move data, for special moves such as en passant or castling */
    const allMoves = myMove ? possibleMoves : GetLegalMoves(board, from, false);
    const move = allMoves.find((v) => v[0] === to);
    if (!move) return;
    const closure = move[1];
    const [moved, movedTo, moveType] = closure?.(board) || [];

    /* Capturing */
    let captured = BitBoard.hasPiece(board, to);
    if (captured) {
      const [piece] = BitBoard.getPiece(board, to);
      if (color === activeGame.color)
        setPlayer1taken((prev) => [...prev, piece]);
      else setPlayer2taken((prev) => [...prev, piece]);
    }

    /* Simple piece move with promotion */
    if (!as) BitBoard.movePiece(board, from, to); /* normal move */
    else {
      BitBoard.setPiece(board, from, 0, 0);
      BitBoard.setPiece(board, to, as, color);
    }
    BitBoard.flipTurn(board);

    /* Animate */
    if (dragging) {
      chessBoardRef.current?.setBoard(board);
    } else {
      chessBoardRef.current?.animateBoard(
        from,
        to,
        as ? [as, color] : undefined,
        moved ? [moved, movedTo] : undefined,
      );
    }
    /* Sound effects */
    let sfx: Parameters<typeof playSFX>[0] = "Move";
    const opponentsKing = BitBoard.findPiece(
      board,
      PieceType.king,
      1 - color,
    )[0];
    if (IsSquareAttacked(board, opponentsKing, color)) {
      sfx = "Check";
    } else if (moveType === "castle") {
      sfx = "Castle";
    } else if (captured) {
      sfx = "Capture";
    }

    playSFX(sfx);

    /* Update local board, and let server know */
    if (pushPGN) {
      Atoms.PGN((x) => {
        PGN.move(x, board, from, to, as, captured, sfx);
        return x;
      });
    }
    Atoms.CurrentMove(pgn.size() - 1);
    Atoms.Board(BitBoard.branch(board));

    if (myMove) {
      Atoms.PossibleMoves([]);
      Events.MakeMove(gameId, [from, to, as]);
    } else if (holdingPiece) {
      Atoms.PossibleMoves(GetLegalMoves(board, holdingPiece, true, playingAs));
    }

    print(FEN.toFEN(board));
  };

  /* Handlers */
  const onMove = (location: number) => {
    if (
      !possibleMoves.find((v) => v[0] === location) ||
      holdingPiece === undefined
    )
      return;

    if (BitBoard.getTurn(board) !== playingAs) {
      /* PREMOVE! */
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

    movePiece(holdingPiece, location, true);
  };
  const onPromote = (piece?: PieceType) => {
    if (!holdingPiece || !piece) {
      setPromoting(-1);
      return;
    }
    movePiece(holdingPiece, promoting, true, piece);
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
    playSFX(pgn[moveIndex].moveType as Parameters<typeof playSFX>[0]);
    Atoms.CurrentMove(moveIndex);
    Atoms.PossibleMoves([]);
  };

  /* Events */
  useEventListener(Events.PatchGame, (activeGame) => {
    if (activeGame.eval) evalBarRef.current?.setEval(activeGame.eval);
    if (activeGame.mate) evalBarRef.current?.setMate(activeGame.mate);
    if (activeGame.opening) setOpening(activeGame.opening);

    setGame((g) => ({ ...g, ...activeGame }));
  });
  useEventListener(Events.MoveMade, (move, turn) => {
    if (turn === playingAs) return; /* i am already this color */
    movePiece(move[0], move[1], false, move[2]);
  });
  useEventListener(Events.AssignedGame, (gameId, color) => {
    setPlayingAs(color);
    setGameId(gameId);
    setOpening("Starting Position");
    chessBoardRef.current?.setBoard(board);
    pgn.clear();
  });
  useEffect(() => {
    chessBoardRef.current?.setBoard(BitBoard.branch(DefaultBoard));
    Events.NewGame();
  }, []);
  useInterval(() => {
    /* local time counter */
    if (activeGame.analysis !== "") return;

    if (isPlayer1Turn) {
      setGame((g) => ({ ...g, player1time: (g.player1time ?? 0) - 0.1 }));
    } else {
      setGame((g) => ({ ...g, player2time: (g.player2time ?? 0) - 0.1 }));
    }
  }, 0.1);

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
          rating={2412}
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
          rating={3674}
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
            gameId === "" ||
            activeGame.analysis !== "" ||
            /* if the PGN is not empty, then if the currentMove is not
          the last move  (rewinding) */
            (pgn.size() === 0 ? false : currentMove !== pgn.size() - 1)
          }
          size={new UDim2(0.85, 0, 0.85, 0)}
        />
      </Frame>

      <Explorer
        opening={opening}
        currentMove={currentMove}
        onRewind={onRewind}
      />
    </Frame>
  );
}
