import { atom } from "@rbxts/charm";
import { Square } from "shared/board";

import { Move } from "shared/engine/bitboard";

const Atoms = {
  Dragging: atom<boolean>(false),
  CurrentMove: atom<Square>(0),
  CheckedSquare: atom<Square>(-1),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Move[]>([]),
  ViewingPlayer: atom<number>(0) /* userid */,
};

export default Atoms;
