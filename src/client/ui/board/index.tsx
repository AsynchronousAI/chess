import React, { useEffect, useMemo, useState } from "@rbxts/react";
import { Color, FILES, RANKS } from "shared/board";
import { Piece } from "./piece";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Wood } from "./images";
import { Frame } from "@rbxts/better-react-components";
import { Square } from "./square";
import { GetAllLegalMoves } from "shared/engine/legalMoves";
import { Notation } from "shared/engine/notation";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const iconPack = Wood;

  print(
    GetAllLegalMoves(board, 0, false).map(
      ([a, b]) => Notation.encodeSquare(a) + " -> " + Notation.encodeSquare(b),
    ),
  );

  return (
    <Frame
      size={new UDim2(1, 0, 1, 0)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      aspectRatio={1}
    >
      {FILES.map((letter, i) =>
        RANKS.map((number, j) => (
          <>
            <Square
              letter={letter}
              number={number}
              playingAs={Color.white}
              i={i}
              j={j}
              iconPack={iconPack}
            />
            <Piece
              letter={letter}
              number={number}
              playingAs={Color.white}
              i={i}
              j={j}
              iconPack={iconPack}
            />
          </>
        )),
      )}
    </Frame>
  );
}
