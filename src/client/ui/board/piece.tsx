import React, { useRef, useState } from "@rbxts/react";

import { Image } from "../image";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Board, Color, IsSquareBlack, Square } from "shared/board";
import { IconPack } from "./images";
import { useBindingListener, useBindingState } from "@rbxts/pretty-react-hooks";
import { useMouse, useMotion } from "@rbxts/pretty-react-hooks";
import GetLegalMoves from "shared/engine/legalMoves";

export interface PieceProps {
  letter: string;
  number: string;
  i: number;
  j: number;
  board: Board;
  iconPack: IconPack;
  playingAs: Color;
}
export function Piece(props: PieceProps) {
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const containerRef = useRef<Frame>();
  const possibleMoves = useAtom(Atoms.PossibleMoves);
  const mousePos = useMouse();

  const [rotation, rotationMotion] = useMotion(0);
  const [offsetY, offsetYMotion] = useMotion(0);
  const [mouseRelativePosition, setMouseRelativePosition] = useState(
    new UDim2(),
  );

  useBindingListener(mousePos, (position) => {
    if (holdingPiece !== location || !containerRef.current) {
      rotationMotion.spring(0);
      return;
    }

    const absolutePosition = containerRef.current?.AbsolutePosition;
    const absoluteSize = containerRef.current?.AbsoluteSize;
    if (!absolutePosition || !absoluteSize) return;

    const newOffset = UDim2.fromOffset(
      position.X - absolutePosition.X - absoluteSize.X / 2,
      position.Y - absolutePosition.Y - absoluteSize.Y / 2,
    );
    setMouseRelativePosition(newOffset);

    // based on the current mouseRelativePosition, set rotationMotion to a different value
    const difference = mouseRelativePosition.sub(newOffset).X.Offset;
    const intensity = difference * 1.5;
    if (holdingPiece !== location) {
      rotationMotion.spring(0, { damping: 0.3 });
    } else {
      rotationMotion.spring(intensity, { damping: 0.3 });
    }
  });

  /* Block data */
  const location = `${props.letter}${props.number}` as Square;
  const pieceAtBoard = props.board[location];
  const image = pieceAtBoard
    ? props.iconPack[pieceAtBoard.color][pieceAtBoard.type]
    : undefined;
  const isMyPiece = props.playingAs === pieceAtBoard?.color;
  const boardJ = props.playingAs === "white" ? 7 - props.j : props.j;

  /*** Events */
  const onHover = () => {
    offsetYMotion.spring(isMyPiece ? -10 : 5);
  };
  const onDown = async () => {
    /* TODO: move this to a dedicated file */
    if (holdingPiece === location) {
      /* already holding this piece, revert */
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (isMyPiece) {
      Atoms.HoldingPiece(location); /* pick up piece */
      Atoms.PossibleMoves(GetLegalMoves(props.board, location));
    } else if (possibleMoves.includes(location) && holdingPiece) {
      /* drop here */
      Atoms.Board((currentBoard) => {
        return {
          ...currentBoard,
          [location]: currentBoard[holdingPiece],
          [holdingPiece]: undefined,
        };
      });
      Atoms.PossibleMoves([]);
    }
  };
  const onLeave = () => {
    offsetYMotion.spring(0);
  };

  return (
    <frame
      ref={containerRef}
      key={location}
      Position={
        new UDim2(
          props.i * (1 / 8),
          0,
          boardJ * (1 / 8),
          useBindingState(offsetY),
        )
      }
      Size={new UDim2(1 / 8, 0, 1 / 8, 0)}
      BackgroundTransparency={1}
      BorderSizePixel={0}
      ZIndex={holdingPiece === location ? 100 : 3}
    >
      <textbutton
        Size={new UDim2(1, 0, 1, 0)}
        Text={""}
        BackgroundTransparency={1}
        Event={{
          MouseEnter: onHover,
          MouseLeave: onLeave,
          MouseButton1Down: onDown,
        }}
      />
      {possibleMoves.includes(location) && (
        <frame
          Size={new UDim2(0.35, 0, 0.35, 0)}
          Position={new UDim2(0.5, 0, 0.5, 0)}
          AnchorPoint={new Vector2(0.5, 0.5)}
          BackgroundColor3={new Color3(0, 0, 0)}
          BackgroundTransparency={0.75}
        >
          <uicorner CornerRadius={new UDim(1, 0)} />
        </frame>
      )}
      {image ? (
        <Image
          rotation={rotation}
          image={image}
          position={
            holdingPiece === location ? mouseRelativePosition : undefined
          }
          size={new UDim2(1, 0, 1, 0)}
          outlinePrecision={30}
          outlineThickness={6}
          outlineStartAngle={40}
          outlineColor={new Color3(0.35, 0.35, 0.35)}
          zIndex={holdingPiece === location ? 100 : 3}
        />
      ) : (
        <></>
      )}
    </frame>
  );
}
