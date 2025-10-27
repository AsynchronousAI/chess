import { atom } from "@rbxts/charm";
import { Color, DefaultFEN, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { PGN } from "shared/engine/pgn";

const Atoms = {
  Board: atom<BitBoard>(BitBoard.create(DefaultFEN)),
  PlayingAs: atom<Color>(0),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Square[]>([]),
  PGN: atom<PGN>(
    new PGN({
      black: "Blunderfish",
      white: "Player",
    }),
  ),
};

export default Atoms;
