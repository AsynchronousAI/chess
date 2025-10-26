import { atom } from "@rbxts/charm";
import { Color, DefaultFEN, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";

const Atoms = {
  Board: atom<BitBoard>(new BitBoard(DefaultFEN)),
  PlayingAs: atom<Color>(0),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Square[]>([]),
};

export default Atoms;
