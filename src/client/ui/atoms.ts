import { atom } from "@rbxts/charm";
import { Color, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard } from "shared/engine/fen";

import { Move } from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";

const Atoms = {
  Board: atom<BitBoard>(BitBoard.branch(DefaultBoard)),
  PGN: atom(PGN.create()),
  PlayingAs: atom<Color>(0),
  Dragging: atom<boolean>(false),
  CurrentMove: atom<number>(0),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Move[]>([]),
};

export default Atoms;
