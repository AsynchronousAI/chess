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
  AnalyzeMates,
  default as GetLegalMoves,
  IsSquareAttacked,
} from "shared/engine/legalMoves";
import { BitBoard } from "shared/engine/bitboard";
import { SoundEffects } from "./sfx";
import { Players, SoundService } from "@rbxts/services";
import { usePx } from "../usePx";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { useEventListener } from "@rbxts/pretty-react-hooks";
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

  const px = usePx();
  const iconPack = Vector;

  const chessBoardRef = useRef<ChessBoardRef>(undefined);
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [promoting, setPromoting] = useState<Square>(-1);
  const [analysis, setAnalysis] = useState<ReturnType<typeof AnalyzeMates>>("");
  const [gameId, setGameId] = useState("");
  const [opening, setOpening] = useState("Starting game...");
  const [currentMove, setCurrentMove] = useState<number>(0);
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
        as,
        moved ? [moved, movedTo] : undefined,
      );
    }
    /* Sound effects */
    const opponentsKing = BitBoard.findPiece(
      board,
      PieceType.king,
      1 - color,
    )[0];
    if (IsSquareAttacked(board, opponentsKing, color)) {
      playSFX("Check");
    } else if (moveType === "castle") {
      playSFX("Castle");
    } else if (captured) {
      playSFX("Capture");
    } else {
      playSFX("Move");
    }

    /* Update local board, and let server know */
    if (pushPGN) {
      Atoms.PGN((x) => {
        PGN.move(x, board, from, to, as, captured);
        return x;
      });
    }
    setCurrentMove(pgn.size() - 1);
    Atoms.Board(BitBoard.branch(board));

    if (myMove) {
      Atoms.PossibleMoves([]);
      Events.MakeMove(gameId, [from, to, as]);
    } else if (holdingPiece) {
      Atoms.PossibleMoves(GetLegalMoves(board, holdingPiece, true, playingAs));
    }
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
  const onRewind = (moveIndex: number) => {
    /*if (moveIndex === 0) {
      Atoms.Board(BitBoard.branch(DefaultBoard)); // animate from DefaultBoard
    } else {
      Atoms.Board(pgn[moveIndex - 1].state); // animate from previous
    }
    chessBoardRef.current?.setBoard(Atoms.Board());
    task.wait();
    chessBoardRef.current?.animateBoard(
      pgn[moveIndex].from,
      pgn[moveIndex].to,
      pgn[moveIndex].promotion,
    );*/
    Atoms.Board(pgn[moveIndex].state);
    chessBoardRef.current?.setBoard(pgn[moveIndex].state);
    setCurrentMove(moveIndex);
  };

  /* Events */
  useEventListener(Events.Evaluate, (activeGame) => {
    if (activeGame.eval) evalBarRef.current?.setEval(activeGame.eval);
    if (activeGame.mate) evalBarRef.current?.setMate(activeGame.mate);

    if (activeGame.opening) setOpening(activeGame.opening);

    setGame((g) => ({ ...g, ...activeGame }));
    setAnalysis(AnalyzeMates(board));
  });
  useEventListener(Events.MoveMade, (move, turn) => {
    if (turn === playingAs) return; /* i am already this color */
    movePiece(move[0], move[1], false, move[2]);
  });
  useEventListener(Events.AssignedGame, (gameId, color, activeGame) => {
    setPlayingAs(color);
    setGame((g) => ({ ...g, ...activeGame }));
    setGameId(gameId);
    setOpening("Starting Position");
    chessBoardRef.current?.setBoard(board);
    pgn.clear();
  });
  useEffect(() => {
    chessBoardRef.current?.setBoard(BitBoard.branch(DefaultBoard));
    Events.NewGame();
  }, []);

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
        analysis={analysis}
      />
      <Frame size={new UDim2(1, 0, 0.975, 0)} aspectRatio={1} noBackground>
        <uilistlayout
          VerticalAlignment={"Center"}
          HorizontalAlignment={"Center"}
          FillDirection={"Vertical"}
          Padding={new UDim(0, px(10))}
          SortOrder={"LayoutOrder"}
        />

        <Player
          userId={activeGame.player2 ?? 0}
          flag={"🇺🇸"}
          rating={2412}
          time={50}
          color={1 - (activeGame.color ?? Color.white)}
          valueDifference={
            GetPieceValues(player2taken) - GetPieceValues(player1taken)
          }
          piecesTaken={player2taken}
          iconPack={iconPack}
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
            analysis !== "" ||
            /* if the PGN is not empty, then if the currentMove is not
          the last move  (rewinding) */
            (pgn.size() === 0 ? false : currentMove !== pgn.size() - 1)
          }
          size={new UDim2(0.85, 0, 0.85, 0)}
        />
        <Player
          userId={activeGame.player1 ?? 0}
          flag={"🇺🇸"}
          rating={3674}
          time={892}
          color={activeGame.color ?? Color.white}
          valueDifference={
            GetPieceValues(player1taken) - GetPieceValues(player2taken)
          }
          piecesTaken={player1taken}
          iconPack={iconPack}
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
