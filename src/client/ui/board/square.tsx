import { IsSquareBlack, Square } from "shared/board";
import React from "@rbxts/react";
import { PieceProps } from "./piece";
import { Frame, Text } from "@rbxts/better-react-components";

const DISPLAY_SQUARE_LABELS = true;

export function Square(props: PieceProps) {
  const location = `${props.letter}${props.number}` as Square;
  const colored = IsSquareBlack(props.i, props.j);
  const boardJ = props.playingAs === "white" ? 7 - props.j : props.j;

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
          backgroundTransparency={1}
          size={new UDim2(1, 0, 1, 0)}
          verticalTextAlign="Bottom"
          textAlign="Left"
        />
      )}
    </Frame>
  );
}
