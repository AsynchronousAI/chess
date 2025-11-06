import React, { useState, useRef, useEffect } from "@rbxts/react";
import {
  Color,
  FILES,
  RANKS,
  IsSquareBlack,
  Piece as PieceType,
} from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Wood } from "./images";
import { Frame, ListLayout, Text } from "@rbxts/better-react-components";
import {
  default as GetLegalMoves,
  IsSquareAttacked,
} from "shared/engine/legalMoves";
import { BitBoard } from "shared/engine/bitboard";
import { SoundEffects } from "./sfx";
import { SoundService } from "@rbxts/services";
import { usePx } from "../usePx";
import { Piece } from "./Piece";
import { Promotion } from "./Promotion";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { useEventListener } from "@rbxts/pretty-react-hooks";
import { Events } from "client/network";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();
  const iconPack = Wood;
  const evalBarRef = useRef<EvaluationBarRef>(undefined);

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [pieces, setPieces] = useState(BitBoard.getAllPieces(board));
  const [promoting, setPromoting] = useState(-1);
  const [gameId, setGameId] = useState(-1);
  const [opening, setOpening] = useState("Starting Position");

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
    if (myMove) Events.MakeMove([from, to, as]);
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

  useEventListener(
    Events.MoveMade,
    (move, { eval: evaluation, mate, opening }) => {
      evalBarRef.current?.setEval(evaluation);
      evalBarRef.current?.setMate(mate);

      setOpening(opening);
      movePiece(move[0], move[1], false, move[2]);
    },
  );
  useEventListener(Events.AssignedGame, (color) => {
    setPlayingAs(color);
    setGameId(1);
  });
  useEffect(() => {
    Events.NewGame();
  }, []);

  return (
    <Frame
      size={new UDim2(1, 0, 0.95, 0)}
      noBackground
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
    >
      <ListLayout
        verticalAlign={"Center"}
        horizontalAlign={"Center"}
        direction={"Vertical"}
        padding={px(10)}
      />
      <Text
        background={"#403E39"}
        text={opening}
        textColor={new Color3(1, 1, 1)}
        textSize={px(20)}
        font={"SourceSansSemibold"}
        size={new UDim2(1, 0, 0.05, 0)}
        aspectRatio={20.45}
      />
      <Frame
        size={new UDim2(1, 0, 0.95, 0)}
        noBackground
        position={new UDim2(0.5, 0, 0.5, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
      >
        <ListLayout
          verticalAlign={"Center"}
          horizontalAlign={"Center"}
          direction={"Horizontal"}
          padding={px(10)}
        />

        {/* Eval bar */}
        <EvaluationBar ref={evalBarRef} />

        {/* Board */}
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

              const boardJ = playingAs ? j : 7 - j;

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
                    {boardJ === 7 && (
                      <Text
                        textColor={
                          !colored ? iconPack.filled : iconPack.unfilled
                        }
                        textSize={px(20)}
                        text={letter}
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
                          !colored ? iconPack.filled : iconPack.unfilled
                        }
                        textSize={px(20)}
                        padding={px(3)}
                        text={number}
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
                          MouseButton1Down: () => onMove(index),
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
          {pieces.map(([loc, piece], index) => {
            const pos = BitBoard.separateSquareIndex(loc);
            return (
              <Piece
                key={index}
                pos={pos}
                iconPack={iconPack}
                playingAs={playingAs}
                location={loc}
                piece={piece}
                locked={gameId === -1}
              />
            );
          })}

          {/* Promotion popup */}
          {promoting > 0 ? (
            <Promotion
              color={playingAs}
              iconPack={iconPack}
              location={promoting}
              onPromote={onPromote}
            />
          ) : undefined}
        </Frame>
      </Frame>
    </Frame>
  );
}
