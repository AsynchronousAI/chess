import { atom } from "@rbxts/charm";
import { Board, Color, DefaultBoard, Square } from "shared/board";

const Atoms = {
  /* Board */
  Board: atom<Board>(DefaultBoard),
  PlayingAs: atom<Color>("black"),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Square[]>([]),
};

export default Atoms;
