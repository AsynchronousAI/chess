import React, { useEffect, useState } from "@rbxts/react";
import {
  Color,
  FILES,
  RANKS,
  IsSquareBlack,
  Piece as PieceType,
} from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Wood, IconPack } from "./images";
import { Frame, ListLayout, Text } from "@rbxts/better-react-components";
import {
  AnalyzeMates,
  default as GetLegalMoves,
} from "shared/engine/legalMoves";
import { Image } from "../image";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { BitBoard } from "shared/engine/bitboard";
import { GetBestMoveAPI } from "shared/engine/api";
import { SoundEffects } from "./sfx";
import { Workspace } from "@rbxts/services";
import { usePx } from "../usePx";

export const FLIPPED = false;

export interface PieceProps {
  pos: [number, number];
  location: number;
  iconPack: IconPack;
  playingAs: Color;
  piece: [PieceType, Color];
}

export function Piece(props: PieceProps) {
  const board = useAtom(Atoms.Board);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();

  const [offsetY, offsetYMotion] = useMotion(0);

  const generatePosition = () =>
    new UDim2(
      props.pos[0] / 8,
      0,
      (FLIPPED ? props.pos[1] : 7 - props.pos[1]) / 8,
      0,
    );

  const [pos, posMotion] = useMotion(generatePosition());
  useEffect(
    () =>
      posMotion.tween(generatePosition(), {
        style: Enum.EasingStyle.Quint,
        time: 0.2,
      }),

    [props.pos],
  );

  /* Block data */
  const image = props.piece
    ? props.iconPack[props.piece[1]][props.piece[0]]
    : undefined;
  const isMyPiece =
    props.playingAs === (props.piece ? props.piece[1] : undefined);

  /* Events */
  const onDown = () => {
    if (props.location === undefined || !props.piece) return;

    if (holdingPiece === props.location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (props.piece[0] !== PieceType.none && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(props.location);
      Atoms.PossibleMoves(GetLegalMoves(board, props.location));
    }
  };

  return (
    props.piece[0] !== PieceType.none && (
      <Frame
        position={pos}
        size={new UDim2(1 / 8, 0, 1 / 8, 0)}
        noBackground
        zIndex={holdingPiece === props.location ? 100 : 3}
      >
        <textbutton
          Size={new UDim2(1, 0, 1, 0)}
          Text={""}
          BackgroundTransparency={1}
          ZIndex={1}
          Event={{
            MouseEnter: () => {
              offsetYMotion.spring(isMyPiece ? -10 : 0);
            },
            MouseLeave: () => {
              offsetYMotion.spring(0);
            },
            MouseButton1Down: onDown,
          }}
        />
        {image ? (
          <Image
            image={image}
            position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
            size={new UDim2(1, 0, 1, 0)}
            outlinePrecision={30}
            outlineThickness={px(4)}
            outlineStartAngle={40}
            outlineColor={new Color3(0.35, 0.35, 0.35)}
            zIndex={holdingPiece === props.location ? 100 : 3}
          />
        ) : undefined}
      </Frame>
    )
  );
}
export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();
  const iconPack = Wood;
  const playingAs = Color.white;
  const [pieces, setPieces] = useState(BitBoard.getAllPieces(board));

  /* Evaluation bar */
  const [evaluation, setEval] = useState(0);
  const [mate, setMate] = useState(0);
  const [evalBar, evalBarMotion] = useMotion(0.5);
  const [evalText, setEvalText] = useState("");
  useEffect(() => {
    if (AnalyzeMates(board) === "checkmate") {
      evalBarMotion.spring(mate > 0 ? 1 : 0);
      setEvalText(mate > 0 ? "1-0" : "0-1");
    } else if (mate > 0) {
      evalBarMotion.spring(1);
      setEvalText(`M${mate}`);
    } else if (mate < 0) {
      evalBarMotion.spring(0);
      setEvalText(`M${math.abs(mate - 1)}`);
    } else {
      const scale = 10;
      const probability = 1 / (1 + math.pow(10, -evaluation / scale));
      const mapped = math.min(math.max(probability, 0), 1);

      evalBarMotion.spring(mapped);
      setEvalText(
        string.format("%.1f", evaluation > 0 ? evaluation : 1 - evaluation),
      );
    }
  }, [evaluation, mate, board]);

  /* Utils */
  const playSFX = (sfx: keyof typeof SoundEffects) => {
    const newAudio = new Instance("Sound", Workspace);
    newAudio.SoundId = SoundEffects[sfx];
    newAudio.Play();
    newAudio.Ended.Connect(() => newAudio.Destroy());
  };
  const movePieceInternal = (from: number, to: number, myMove: boolean) => {
    /* this simply moves a piece, and handles additional closures for castling for example */
    const move = (myMove ? possibleMoves : GetLegalMoves(board, from, false))
      /* if it is my move use saved outcomes, otherwise calculate new */
      .find((v) => v[0] === to);
    BitBoard.movePiece(board, from, to);
    BitBoard.flipTurn(board);
    const [moved, movedTo] = move?.[1]?.(board) || [];

    /* do this so we can maintain indexs from a bitboard */
    setPieces((currentPieces) => {
      let captured = false;

      for (const piece of currentPieces) {
        if (piece[0] === from) {
          piece[0] = to;
        } else if (piece[0] === to) {
          piece[1][0] = PieceType.none;
          captured = true;
        } else if (piece[0] === moved) {
          piece[0] = movedTo || 0;
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
  const movePiece = (location: number) => {
    /* this moves a piece, gets an eval, and responds with bot move */
    if (
      !possibleMoves.find((v) => v[0] === location) ||
      holdingPiece === undefined
    )
      return;

    movePieceInternal(holdingPiece, location, true);

    const best = GetBestMoveAPI(board);
    if (!best.move) return;
    setEval(best.eval);
    setMate(best.mate ?? 0);
    movePieceInternal(best.move[0], best.move[1], false);
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
      <Frame size={new UDim2(0.025, 0, 1, 0)} background={"#403E39"}>
        <Frame
          size={evalBar.map((value) => new UDim2(1, 0, value, 0))}
          position={evalBar.map((value) => new UDim2(0, 0, 1 - value, 0))}
          background={new Color3(1, 1, 1)}
        />
        <Text
          visible={evaluation !== 0}
          size={new UDim2(1, 0, 0, px(20))}
          text={evalText}
          noBackground
          textColor={
            evaluation > 0 ? new Color3(0.45, 0.45, 0.45) : new Color3(1, 1, 1)
          }
          font={"SourceSansBold"}
          textSize={px(14)}
          position={
            evaluation > 0
              ? new UDim2(0, 0, 1, -px(25))
              : new UDim2(0, 0, 0, px(2))
          }
        />
      </Frame>

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
          const pos: [number, number] = [loc % 8, math.floor(loc / 8)];
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
      </Frame>
    </Frame>
  );
}
