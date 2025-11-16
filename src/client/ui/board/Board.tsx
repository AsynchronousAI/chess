import { Frame, Text } from "@rbxts/better-react-components";
import React, {
  forwardRef,
  useImperativeHandle,
  useRef,
  useState,
} from "@rbxts/react";
import {
  Color,
  FILES,
  IsSquareBlack,
  RANKS,
  Piece as PieceType,
  Square,
} from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { IconPack } from "./images";
import { Promotion } from "./Promotion";
import { useAtom } from "@rbxts/react-charm";
import { Piece } from "./Piece";
import { HttpService, Players, RunService } from "@rbxts/services";
import { useEventListener } from "@rbxts/pretty-react-hooks";
import { Environment } from "@rbxts/ui-labs";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import Atoms from "../atoms";
import { usePx } from "../hooks/usePx";

export interface ChessBoardProps {
  iconPack: IconPack;
  playingAs: Color;
  promoting: Square;
  onMove: (loc: Square) => void;
  onPromote: (piece?: PieceType) => void;
  locked: boolean;
  size: UDim2;
}
export interface ChessBoardRef {
  setBoard: (board: BitBoard) => void;
  animateBoard: (
    from: number,
    to: number,
    as?: [PieceType, Color],
    closure?: [Square, Square?], // special moves such as en passant and castling use a closure
  ) => void;
}
export const ChessBoard = forwardRef<ChessBoardRef, ChessBoardProps>(
  (props, ref) => {
    const gameplay = useFlameworkDependency<Gameplay>();
    const possibleMoves = useAtom(Atoms.PossibleMoves);
    const pgn = gameplay.usePGN();
    const currentMove = useAtom(Atoms.CurrentMove);

    const px = usePx();
    const containerRef = useRef<Frame>();

    const [pieces, setPieces] = useState<
      [
        number /* location */,
        [PieceType, Color] /* piece information */,
        string /* key, used for animations */,
      ][]
    >([]);
    const [hoveringSquare, setHoveringSquare] = useState<Square | undefined>();

    const UIS = Environment.UserInput;

    const onRelease = () => {
      /* mouse released outside of piece */
      if (Atoms.Dragging() && hoveringSquare !== undefined) {
        props.onMove(hoveringSquare);
      }
      Atoms.Dragging(false);
    };
    const squareHighlighted = (loc: Square) =>
      pgn[currentMove] &&
      (pgn[currentMove].to === loc || pgn[currentMove].from === loc);

    useEventListener(UIS.TouchEnded, onRelease);
    useEventListener(UIS.InputEnded, (input) => {
      if (
        input.KeyCode === Enum.KeyCode.MouseLeftButton ||
        input.KeyCode === Enum.KeyCode.Unknown
      ) {
        onRelease();
      }
    });
    useImperativeHandle(ref, () => ({
      setBoard: (board) => {
        setPieces(
          BitBoard.getAllPieces(board).map(([location, piece]) => [
            location,
            piece,
            HttpService.GenerateGUID(),
          ]),
        );
      },
      animateBoard: (from, to, as, closure) => {
        setPieces((currentPieces) => {
          for (const piece of currentPieces) {
            if (piece[0] === from) {
              piece[0] = to;
              if (as) piece[1] = as;
            } else if (piece[0] === to) {
              piece[1][0] = PieceType.none;
            } else if (closure !== undefined && piece[0] === closure[0]) {
              if (closure[1]) piece[0] = closure[1];
              else piece[1][0] = PieceType.none;
            }
          }
          return currentPieces;
        });
      },
    }));

    return (
      <Frame
        size={props.size}
        aspectRatio={1}
        ref={containerRef}
        layoutOrder={1}
      >
        {/* Squares */}
        {FILES.map((letter, i) =>
          RANKS.map((number, j) => {
            const location = `${letter}${number}`;
            const index = BitBoard.getSquareIndex(i, j);
            const colored = IsSquareBlack(i, j);

            const boardJ = props.playingAs ? j : 7 - j;

            return (
              <>
                {/* Square background */}
                <Frame
                  key={`${location}-square`}
                  position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                  size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                  background={
                    squareHighlighted(index)
                      ? props.iconPack.highlighted
                      : colored
                        ? props.iconPack.filled
                        : props.iconPack.unfilled
                  }
                  zIndex={1}
                >
                  {boardJ === 7 && (
                    <Text
                      textColor={
                        !colored
                          ? props.iconPack.filled
                          : props.iconPack.unfilled
                      }
                      textSize={px(20)}
                      text={props.playingAs === 1 ? FILES[7 - i] : FILES[i]}
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
                        !colored
                          ? props.iconPack.filled
                          : props.iconPack.unfilled
                      }
                      textSize={px(20)}
                      padding={px(3)}
                      text={RANKS[j]}
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
                  <>
                    <textbutton
                      key={`${location}-hit`}
                      Position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                      Size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                      Text={""}
                      BackgroundTransparency={1}
                      ZIndex={1000}
                      Event={{
                        MouseButton1Down: () => props.onMove(index),
                        MouseEnter: () => setHoveringSquare(index),
                        MouseLeave: () => setHoveringSquare(undefined),
                      }}
                    />
                    <Frame
                      key={`${location}-hit-visual`}
                      position={new UDim2(i * (1 / 8), 0, boardJ * (1 / 8), 0)}
                      size={new UDim2(1 / 8, 0, 1 / 8, 0)}
                      noBackground
                      zIndex={25}
                    >
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
                  </>
                )}
              </>
            );
          }),
        )}

        {/* Pieces */}
        {pieces.map(([loc, piece, key]) => {
          const pos = BitBoard.separateSquareIndex(loc);
          return (
            <Piece
              key={key}
              pos={pos}
              iconPack={props.iconPack}
              playingAs={props.playingAs}
              location={loc}
              piece={piece}
              locked={props.locked}
              containerRef={containerRef}
              onRelease={onRelease}
            />
          );
        })}

        {/* Promotion popup */}
        {props.promoting > 0 ? (
          <Promotion
            color={props.playingAs}
            iconPack={props.iconPack}
            location={props.promoting}
            onPromote={props.onPromote}
          />
        ) : undefined}
      </Frame>
    );
  },
);
