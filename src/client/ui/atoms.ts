import { atom } from "@rbxts/charm";
import { Color, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard } from "shared/engine/fen";

import { Move } from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";
import { EndgamePopupProps } from "./endgamePopup";

const Atoms = {
  Board: atom<BitBoard>(BitBoard.branch(DefaultBoard)),
  PGN: atom(PGN.create()),
  PlayingAs: atom<Color>(0),
  Dragging: atom<boolean>(false),
  CurrentMove: atom<number>(0),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Move[]>([]),
  Popup: atom<EndgamePopupProps>({
    title: "",
    rating: 0,
    ratingChange: 0,
    description: "",
    open: false,
  }),
};

export default Atoms;
