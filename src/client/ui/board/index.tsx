import React, { useState, useRef, useEffect } from "@rbxts/react";
import { Color, Piece as PieceType, Square } from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Vector, Wood } from "./images";
import {
  Button,
  Frame,
  ListLayout,
  ScrollingFrame,
  Text,
} from "@rbxts/better-react-components";
import {
  AnalyzeMates,
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
import { ChessBoard, ChessBoardRef } from "./Board";
import { PGN } from "shared/engine/pgn";
import { DefaultBoard, FEN } from "shared/engine/fen";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const pgn = useAtom(Atoms.PGN);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const dragging = useAtom(Atoms.Dragging);

  const px = usePx();
  const iconPack = Wood;

  const chessBoardRef = useRef<ChessBoardRef>(undefined);
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [promoting, setPromoting] = useState<Square>(-1);
  const [analysis, setAnalysis] = useState<ReturnType<typeof AnalyzeMates>>("");
  const [gameId, setGameId] = useState("");
  const [opening, setOpening] = useState("Starting game...");
  const [currentMove, setCurrentMove] = useState<number>(0);

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
    const [moved, movedTo, moveType] = move?.[1]?.(board) || [];

    /* Simple piece move with promotion */
    let captured = BitBoard.hasPiece(board, to);
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
      holdingPiece === undefined ||
      BitBoard.getTurn(board) !== playingAs
    )
      return;

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

  useEventListener(Events.Evaluate, (activeGame) => {
    if (activeGame.eval) evalBarRef.current?.setEval(activeGame.eval);
    if (activeGame.mate) evalBarRef.current?.setMate(activeGame.mate);

    if (activeGame.opening) setOpening(activeGame.opening);

    setAnalysis(AnalyzeMates(board));
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

      <EvaluationBar
        ref={evalBarRef}
        size={new UDim2(0.025, 0, 0.85, 0)}
        analysis={analysis}
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

      {/* Explorer */}
      <ScrollingFrame
        size={new UDim2(0.5, 0, 0.85, 0)}
        position={new UDim2(0.5, 0, 0.5, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        background={new Color3(0.1, 0.1, 0.1)}
        canvasSize={new UDim2(0.5, 0, 0, 0)}
        scrollbar={{
          topImage: "rbxassetid://3062506215",
          bottomImage: "rbxassetid://3062506215",
          midImage: "rbxassetid://3062506215",
          imageTransparency: 0.5,
          imageColor: new Color3(1, 1, 1),
        }}
        direction={"Y"}
        automaticCanvasSize={"Y"}
      >
        <ListLayout
          direction={"Vertical"}
          verticalAlign={"Top"}
          horizontalAlign={"Center"}
          order={"LayoutOrder"}
        />
        <Text
          background={"#403E39"}
          text={opening}
          textColor={new Color3(1, 1, 1)}
          textSize={px(20)}
          font={"SourceSansSemibold"}
          size={new UDim2(1, 0, 0, px(45))}
          layoutOrder={0}
        />

        {pgn
          .filter((_, i) => i % 2 === 0) // only white moves, since black moves will be displayed same place
          .map((move, minimizedIndex) => {
            const index = minimizedIndex * 2;
            const blackResponse = pgn[index + 1];
            return (
              <Frame
                layoutOrder={minimizedIndex}
                size={new UDim2(1, 0, 0, px(35))}
                background={minimizedIndex % 2 === 0 ? "#403E39" : "#282723"}
                key={minimizedIndex}
                backgroundTransparency={0.5}
                padding={px(5)}
                paddingLeft={px(10)}
              >
                <ListLayout
                  direction={"Horizontal"}
                  verticalAlign={"Center"}
                  horizontalAlign={"Left"}
                  order={"LayoutOrder"}
                  padding={px(15)}
                />
                <Text
                  text={`${minimizedIndex + 1}.`}
                  textColor={new Color3(0.6, 0.6, 0.6)}
                  textSize={px(20)}
                  font={"SourceSansSemibold"}
                  textAlign={"Left"}
                  size={new UDim2(0.05, 0, 1, 0)}
                  noBackground
                />

                {/* White move */}
                <textbutton
                  Text={move.notation}
                  TextColor3={
                    index === currentMove
                      ? new Color3(1, 1, 1)
                      : new Color3(0.8, 0.8, 0.8)
                  }
                  TextSize={px(20)}
                  Font={"SourceSansSemibold"}
                  Size={new UDim2(0, 0, 1, 0)}
                  AutomaticSize={"X"}
                  BackgroundTransparency={1}
                  Event={{
                    MouseButton1Click: () => onRewind(index),
                  }}
                />

                {/* Black move */}
                {blackResponse !== undefined && (
                  <textbutton
                    Text={blackResponse.notation}
                    TextColor3={
                      index + 1 === currentMove
                        ? new Color3(1, 1, 1)
                        : new Color3(0.8, 0.8, 0.8)
                    }
                    TextSize={px(20)}
                    Font={"SourceSansSemibold"}
                    Size={new UDim2(0, 0, 1, 0)}
                    AutomaticSize={"X"}
                    BackgroundTransparency={1}
                    Event={{
                      MouseButton1Click: () => onRewind(index + 1),
                    }}
                  />
                )}
              </Frame>
            );
          })}
      </ScrollingFrame>
    </Frame>
  );
}
