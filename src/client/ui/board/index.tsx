import React, { useState, useRef, useEffect } from "@rbxts/react";
import { Color, Piece as PieceType } from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Vector, Wood } from "./images";
import { Frame, Text } from "@rbxts/better-react-components";
import {
  default as GetLegalMoves,
  IsSquareAttacked,
} from "shared/engine/legalMoves";
import { BitBoard } from "shared/engine/bitboard";
import { SoundEffects } from "./sfx";
import { SoundService } from "@rbxts/services";
import { usePx } from "../usePx";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { useEventListener } from "@rbxts/pretty-react-hooks";
import { Events } from "client/network";
import ChessBoard from "./Board";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();
  const iconPack = Vector;
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [pieces, setPieces] = useState(BitBoard.getAllPieces(board));
  const [promoting, setPromoting] = useState(-1);
  const [gameId, setGameId] = useState("");
  const [opening, setOpening] = useState("Starting game...");

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
    myMove: boolean,
    as?: PieceType,
  ) => {
    const color = myMove ? playingAs : 1 - playingAs;

    /* Locate the move data, for special moves such as en passant or castling */
    const allMoves = myMove ? possibleMoves : GetLegalMoves(board, from, false);
    const move = allMoves.find((v) => v[0] === to);
    const [moved, movedTo, moveType] = move?.[1]?.(board) || [];

    /* Simple piece move with promotion */
    if (!as) BitBoard.movePiece(board, from, to); /* normal move */
    else {
      BitBoard.setPiece(board, from, 0, 0);
      BitBoard.setPiece(board, to, as, color);
    }
    BitBoard.flipTurn(board);

    /* Move on a set index, for animations */
    let captured = false;
    setPieces((currentPieces) => {
      for (const piece of currentPieces) {
        if (piece[0] === from) {
          piece[0] = to;
          if (as) piece[1][0] = as;
        } else if (piece[0] === to) {
          piece[1][0] = PieceType.none;
          captured = true;
        } else if (piece[0] === moved) {
          if (movedTo) piece[0] = movedTo;
          else piece[1][0] = PieceType.none;
        }
      }
      return currentPieces;
    });

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
    Atoms.Board(BitBoard.branch(board));
    Atoms.PossibleMoves([]);
    if (myMove) Events.MakeMove(gameId, [from, to, as]);
  };

  /* Handlers */
  const onMove = (location: number) => {
    if (
      !possibleMoves.find((v) => v[0] === location) ||
      holdingPiece === undefined
    )
      return;

    const piece = BitBoard.getPiece(board, holdingPiece);
    if (
      piece[0] === PieceType.pawn &&
      (playingAs === Color.white ? location > 49 : location < 8)
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

  useEventListener(Events.Evaluate, (activeGame) => {
    if (activeGame.eval) evalBarRef.current?.setEval(activeGame.eval);
    if (activeGame.mate) evalBarRef.current?.setMate(activeGame.mate);

    if (activeGame.opening) setOpening(activeGame.opening);
  });
  useEventListener(Events.MoveMade, (move, turn) => {
    if (turn === playingAs) return; /* i am already this color */
    movePiece(move[0], move[1], false, move[2]);
  });
  useEventListener(Events.AssignedGame, (gameId, color) => {
    setPlayingAs(color);
    setGameId(gameId);
  });
  useEffect(() => {
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
        Padding={new UDim(0, px(10))}
      />

      <EvaluationBar ref={evalBarRef} size={new UDim2(0.025, 0, 0.9, 0)} />

      <ChessBoard
        iconPack={iconPack}
        playingAs={playingAs}
        onPromote={onPromote}
        onMove={onMove}
        promoting={promoting}
        locked={gameId === ""}
        pieces={pieces}
        size={new UDim2(0.9, 0, 0.9, 0)}
      />

      <Text
        background={"#403E39"}
        text={opening}
        textColor={new Color3(1, 1, 1)}
        textSize={px(20)}
        font={"SourceSansSemibold"}
        size={new UDim2(0.5, 0, 0.05, 0)}
      />
    </Frame>
  );
}
