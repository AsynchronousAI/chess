import React, { Binding, useEffect, useState } from "@rbxts/react";
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
import {
  CanvasGroup,
  Frame,
  ListLayout,
  Text,
} from "@rbxts/better-react-components";
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
import { Motion } from "@rbxts/ripple";

export const FLIPPED = false;
const BOT = true;

export interface PieceProps {
  pos: [number, number];
  location: number;
  iconPack: IconPack;
  playingAs: Color;
  piece: [PieceType, Color];
}

const generatePosition = (pos: [number, number]) =>
  new UDim2(pos[0] / 8, 0, (FLIPPED ? pos[1] : 7 - pos[1]) / 8, 0);

export function Promotion({
  location,
  color,
  iconPack,
  onPromote,
}: {
  location: number;
  color: Color;
  iconPack: IconPack;
  onPromote: (piece: PieceType | undefined) => void;
}) {
  const px = usePx();
  const holdingPiece = useAtom(Atoms.HoldingPiece);

  const pieces = [
    PieceType.bishop,
    PieceType.rook,
    PieceType.knight,
    PieceType.queen,
  ];
  const motions = pieces.map(() => [...useMotion(0)]) as [
    Binding<number>,
    Motion<number>,
  ][];

  const pos = [location % 8, math.floor(location / 8)] as [number, number];

  return (
    <CanvasGroup
      position={generatePosition(pos).add(
        color === Color.white && !FLIPPED
          ? new UDim2()
          : new UDim2(0, 0, -0.435, 0),
      )}
      size={new UDim2(1 / 8, 0, 4.5 / 8, 0)}
      zIndex={1000}
      background={new Color3(1, 1, 1)}
      cornerRadius={px(4)}
    >
      <ListLayout
        verticalAlign={"Top"}
        horizontalAlign={"Center"}
        direction={"Vertical"}
        order={"LayoutOrder"}
        padding={px(5)}
      />

      {/* Close */}
      <textbutton
        Font={"ArialBold"}
        TextSize={px(18)}
        Size={new UDim2(1, 0, 1 / 9, 0)}
        Text="X"
        TextColor3={new Color3(0.35, 0.35, 0.35)}
        BackgroundColor3={new Color3(0.95, 0.95, 0.95)}
        LayoutOrder={0}
        AutoButtonColor={false}
        Event={{
          MouseButton1Click: () => onPromote(undefined),
        }}
      >
        <uistroke
          Thickness={px(1)}
          Color={new Color3(0.85, 0.85, 0.85)}
          ApplyStrokeMode={"Border"}
        />
      </textbutton>

      {/* Options */}
      {pieces.map((piece, index) => {
        const [offsetY, offsetYMotion] = motions[index];
        return (
          <Frame
            size={new UDim2(1, -px(7), 1, -px(7))}
            noBackground
            zIndex={holdingPiece === location ? 100 : 3}
            key={index}
            layoutOrder={index + 1}
          >
            <uiaspectratioconstraint AspectRatio={1} />
            <textbutton
              Size={new UDim2(1, 0, 1, 0)}
              Text={""}
              BackgroundTransparency={1}
              ZIndex={1}
              Event={{
                MouseEnter: () => offsetYMotion.spring(-10),
                MouseLeave: () => offsetYMotion.spring(0),
                MouseButton1Click: () => onPromote(piece),
              }}
            />
            <Image
              image={iconPack[color][piece]!}
              position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
              size={new UDim2(1, 0, 1, 0)}
              outlinePrecision={30}
              outlineThickness={px(4)}
              outlineStartAngle={40}
              outlineColor={new Color3(0.35, 0.35, 0.35)}
              zIndex={holdingPiece === location ? 100 : 3}
            />
          </Frame>
        );
      })}
    </CanvasGroup>
  );
}
export function Piece(props: PieceProps) {
  const board = useAtom(Atoms.Board);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();

  const [offsetY, offsetYMotion] = useMotion(0);

  const [pos, posMotion] = useMotion(generatePosition(props.pos));
  useEffect(
    () =>
      posMotion.tween(generatePosition(props.pos), {
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
      <>
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
      </>
    )
  );
}
export default function Board() {
  const board = useAtom(Atoms.Board);
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();
  const iconPack = Wood;

  const [playingAs, setPlayingAs] = useState(Color.white);
  const [pieces, setPieces] = useState(BitBoard.getAllPieces(board));
  const [promoting, setPromoting] = useState(-1);

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
  const movePieceInternal = (
    from: number,
    to: number,
    myMove: boolean,
    as?: PieceType,
  ) => {
    /* this simply moves a piece, and handles additional closures for castling for example */
    const move = (myMove ? possibleMoves : GetLegalMoves(board, from, false))
      /* if it is my move use saved outcomes, otherwise calculate new */
      .find((v) => v[0] === to);
    if (!as) BitBoard.movePiece(board, from, to); /* normal move */
    else {
      BitBoard.setPiece(board, from, 0, 0);
      BitBoard.setPiece(board, to, as, playingAs);
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
  const onPieceMove = () => {
    const best = GetBestMoveAPI(board);
    if (best.move) {
      setEval(best.eval);
      setMate(tonumber(best.mate) ?? 0);
    }

    if (BOT && best.move) {
      movePieceInternal(best.move[0], best.move[1], false);
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

        {/* Promotion popup */}
        {promoting > 0 ? (
          <Promotion
            color={playingAs}
            iconPack={iconPack}
            location={promoting}
            onPromote={(piece) => {
              if (!holdingPiece) return;
              movePieceInternal(holdingPiece, promoting, true, piece);
              onPieceMove();
              setPromoting(-1);
              print("promote to", piece);
            }}
          />
        ) : undefined}
      </Frame>
    </Frame>
  );
}
