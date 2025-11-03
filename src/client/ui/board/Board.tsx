import React, { useEffect, useState, useRef } from "@rbxts/react";
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
import { default as GetLegalMoves } from "shared/engine/legalMoves";
import { BitBoard } from "shared/engine/bitboard";
import { GetBestMoveAPI } from "shared/engine/api";
import { SoundEffects } from "./sfx";
import { Workspace } from "@rbxts/services";
import { usePx } from "../usePx";
import { Piece } from "./Piece";
import { Promotion } from "./Promotion";
import { EvaluationBar, EvaluationBarRef } from "./EvaluationBar";
import { BOT, FLIPPED } from "./shared";
import { FEN } from "shared/engine/fen";

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

  /* Utils */
  const playSFX = (sfx: keyof typeof SoundEffects) => {
    const newAudio = new Instance("Sound", Workspace);
    newAudio.SoundId = SoundEffects[sfx];
    newAudio.Play();
    newAudio.Ended.Connect(() => newAudio.Destroy());
  };
  const movePieceInternal = (
    from: number,
    to: number,
    myMove: boolean,
    as?: PieceType,
  ) => {
    /* this simply moves a piece, and handles additional closures for castling for example */
    const allMoves = myMove ? possibleMoves : GetLegalMoves(board, from, false);
    const move = allMoves
      /* if it is my move use saved outcomes, otherwise calculate new */
      .find((v) => v[0] === to);

    if (!as) BitBoard.movePiece(board, from, to); /* normal move */
    else {
      BitBoard.setPiece(board, from, 0, 0);
      BitBoard.setPiece(board, to, as, myMove ? playingAs : 1 - playingAs);
    }
    BitBoard.flipTurn(board);
    const [moved, movedTo] = move?.[1]?.(board) || [];

    /* do this so we can maintain indexs from a bitboard */
    setPieces((currentPieces) => {
      let captured = false;

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

      if (captured) {
        playSFX("Capture");
      } else {
        playSFX("Move");
      }
      return currentPieces;
    });
    Atoms.Board(BitBoard.branch(board));
    Atoms.PossibleMoves([]);
  };
  const onPieceMove = async () => {
    const best = GetBestMoveAPI(board);
    if (best.move) {
      evalBarRef.current?.setEval(best.eval);
      evalBarRef.current?.setMate(tonumber(best.mate) ?? 0);
    }

    if (BOT && best.move) {
      movePieceInternal(best.move[0], best.move[1], false, best.move[2]);
    } else {
      setPlayingAs((p) => 1 - p);
    }
  };
  const movePiece = (location: number) => {
    /* this moves a piece, gets an eval, and responds with bot move */
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

    movePieceInternal(holdingPiece, location, true);
    onPieceMove();
  };

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
                  {boardJ === 7 && (
                    <Text
                      textColor={!colored ? iconPack.filled : iconPack.unfilled}
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
                      textColor={!colored ? iconPack.filled : iconPack.unfilled}
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
            />
          );
        })}

        {/* Promotion popup */}
        {promoting > 0 ? (
          <Promotion
            color={playingAs}
            iconPack={iconPack}
            location={promoting}
            onPromote={(piece) => {
              if (!holdingPiece || !piece) {
                setPromoting(-1);
                return;
              }
              movePieceInternal(holdingPiece, promoting, true, piece);
              onPieceMove();
              setPromoting(-1);
            }}
          />
        ) : undefined}
      </Frame>
    </Frame>
  );
}
