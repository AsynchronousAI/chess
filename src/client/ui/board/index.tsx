import React, { Binding, useEffect, useRef, useState } from "@rbxts/react";
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
import { default as GetLegalMoves } from "shared/engine/legalMoves";
import { Image } from "../image";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { BitBoard } from "shared/engine/bitboard";
import { GetBestMoveAPI } from "shared/engine/api";
import { SoundEffects } from "./sfx";
import { Workspace } from "@rbxts/services";
import { usePx } from "../usePx";

const DISPLAY_SQUARE_LABELS = true;
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
        style: Enum.EasingStyle.Quad,
        time: 0.1,
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
    if (!props.location || !props.piece) return;

    if (holdingPiece === props.location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (props.piece[0] !== 0 && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(props.location);
      Atoms.PossibleMoves(GetLegalMoves(board, props.location));
    }
  };

  return (
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
  );
}
export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();

  const [evaluation, setEval] = useState(0);
  const [evalBar, evalBarMotion] = useMotion(0.5);
  useEffect(() => {
    const scale = 10;
    const probability = 1 / (1 + math.pow(10, -evaluation / scale));
    const mapped = math.min(math.max(probability, 0), 1);

    evalBarMotion.spring(mapped);
  }, [evaluation]);

  const iconPack = Wood;

  const [pieces, setPieces] = useState(BitBoard.getAllPieces(board));

  const playSFX = (sfx: keyof typeof SoundEffects) => {
    const newAudio = new Instance("Sound", Workspace);
    newAudio.SoundId = SoundEffects[sfx];
    newAudio.Play();
    newAudio.Ended.Connect(() => newAudio.Destroy());
  };
  const movePieceInternal = (from: number, to: number) => {
    BitBoard.movePiece(board, from, to);
    BitBoard.flipTurn(board);

    /* do this so we can maintain indexs from a bitboard */
    setPieces((currentPieces) => {
      let captured = false;

      for (const piece of currentPieces) {
        if (piece[0] === from) {
          piece[0] = to;
        } else if (piece[0] === to) {
          piece[1][0] = PieceType.none;
          captured = true;
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
    if (!possibleMoves.includes(location) || !holdingPiece) return;

    movePieceInternal(holdingPiece, location);

    const best = GetBestMoveAPI(board);
    if (!best.move) return;
    setEval(best.eval);
    movePieceInternal(best.move[0], best.move[1]);
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
      <Frame size={new UDim2(0, px(25), 1, 0)} background={"#403E39"}>
        <Frame
          size={evalBar.map((value) => new UDim2(1, 0, value, 0))}
          position={evalBar.map((value) => new UDim2(0, 0, 1 - value, 0))}
          background={new Color3(1, 1, 1)}
        />
        <Text
          size={new UDim2(1, 0, 0, px(20))}
          text={string.format(
            "%.1f",
            evaluation > 0 ? evaluation : 1 - evaluation,
          )}
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
                  {DISPLAY_SQUARE_LABELS && (
                    <Text
                      textColor={!colored ? iconPack.filled : iconPack.unfilled}
                      textSize={px(17)}
                      text={location}
                      font={"SourceSansBold"}
                      backgroundTransparency={1}
                      size={new UDim2(1, 0, 1, 0)}
                      verticalTextAlign="Bottom"
                      textAlign="Left"
                    />
                  )}
                </Frame>

                {/* Hitbox */}
                {possibleMoves.includes(index) && (
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
              playingAs={Color.white}
              location={loc}
              piece={piece}
            />
          );
        })}
      </Frame>
    </Frame>
  );
}
