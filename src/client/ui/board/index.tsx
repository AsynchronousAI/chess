import React, { useMemo, useState } from "@rbxts/react";
import { FILES, RANKS } from "shared/board";
import { Piece } from "./piece";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Vector, Flat, Wood } from "./images";
import { Frame } from "@rbxts/better-react-components";
import { Square } from "./square";

export default function Board() {
  const board = useAtom(Atoms.Board);
  const playingAs = useAtom(Atoms.PlayingAs);
  const iconPack = Wood;

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
              i={i}
              j={j}
              playingAs={playingAs}
              board={board}
              iconPack={iconPack}
            />
            <Piece
              letter={letter}
              number={number}
              i={i}
              j={j}
              playingAs={playingAs}
              board={board}
              iconPack={iconPack}
            />
          </>
        )),
      )}
    </Frame>
  );
}
