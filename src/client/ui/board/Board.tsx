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
import { HttpService, RunService } from "@rbxts/services";
import { useEventListener } from "@rbxts/pretty-react-hooks";
import { Environment } from "@rbxts/ui-labs";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import Atoms from "../atoms";
import { usePx } from "../hooks/usePx";
import { Move } from "shared/engine/move";
import { Object } from "@rbxts/luau-polyfill";

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
  animateBoard: (moved: [Square, Square?, PieceType?][]) => void;
}
export const ChessBoard = forwardRef<ChessBoardRef, ChessBoardProps>(
  (props, ref) => {
    const gameplay = RunService.IsRunning()
      ? useFlameworkDependency<Gameplay>()
      : undefined;
    const possibleMoves = useAtom(Atoms.PossibleMoves);
    const movehistory = gameplay?.useMoveHistory() ?? [];
    const currentMove = useAtom(Atoms.CurrentMove);
    const checked = useAtom(Atoms.CheckedSquare);

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
      setHoveringSquare(undefined);
    };
    const squareHighlighted = (loc: Square) =>
      movehistory[currentMove] &&
      (Move.getTo(movehistory[currentMove].move) === loc ||
        Move.getFrom(movehistory[currentMove].move) === loc);
    const squareChecked = (loc: Square) => checked === loc;

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
          BitBoard.get_all_pieces(board).map(([piece, color, location]) => [
            location,
            [piece, color],
            HttpService.GenerateGUID(),
          ]),
        );
      },
      animateBoard: (moved) => {
        setPieces((currentPieces) => {
          let updatedPieces = [...currentPieces];
          for (const move of moved) {
            const [from, to, pieceType] = move;

            /* Remove any pieces already at to */
            let index = updatedPieces.findIndex((x) => x[0] === to);
            if (index !== -1) {
              updatedPieces.remove(index);
            }

            /* Move a piece here */
            index = updatedPieces.findIndex((x) => x[0] === from);
            if (index !== -1 && to) {
              // move
              updatedPieces[index] = [
                to,
                [
                  pieceType ?? updatedPieces[index][1][0],
                  updatedPieces[index][1][1],
                ],
                updatedPieces[index][2],
              ];
            }
          }
          return updatedPieces;
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
            const index = BitBoard.get_square_index(i, j);
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
                      : squareChecked(index)
                        ? props.iconPack.checked
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
                {possibleMoves.find((v) => Move.getTo(v) === index) && (
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
          const pos = BitBoard.separate_square_index(loc);
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
