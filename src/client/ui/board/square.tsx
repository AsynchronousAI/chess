import { IsSquareBlack, Square } from "shared/board";
import React from "@rbxts/react";
import { PieceProps } from "./piece";
import { Frame, Text } from "@rbxts/better-react-components";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";

const DISPLAY_SQUARE_LABELS = true;
export const FLIPPED = false;

export function Square(props: PieceProps) {
  const board = useAtom(Atoms.Board);

  const location = `${props.letter}${props.number}`;
  const colored = IsSquareBlack(props.i, props.j);

  const boardJ = FLIPPED ? props.j : 7 - props.j;

  return (
    <Frame
      key={`${location}-s`}
      position={new UDim2(props.i * (1 / 8), 0, boardJ * (1 / 8), 0)}
      size={new UDim2(1 / 8, 0, 1 / 8, 0)}
      background={colored ? props.iconPack.filled : props.iconPack.unfilled}
      zIndex={1}
    >
      {DISPLAY_SQUARE_LABELS && (
        <Text
          textColor={!colored ? props.iconPack.filled : props.iconPack.unfilled}
          textSize={24}
          text={location}
          font={"SourceSansBold"}
          backgroundTransparency={1}
          size={new UDim2(1, 0, 1, 0)}
          verticalTextAlign="Bottom"
          textAlign="Left"
        />
      )}
    </Frame>
  );
}
