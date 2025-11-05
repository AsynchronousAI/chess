import { atom } from "@rbxts/charm";
import { Color, DefaultFEN, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { FEN } from "shared/engine/fen";
import { Move } from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";

const Atoms = {
  Board: atom<BitBoard>(FEN.fromFEN(DefaultFEN)),
  PlayingAs: atom<Color>(0),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Move[]>([]),
  PGN: atom<PGN>(
    new PGN({
      black: "Blunderfish",
      white: "Player",
    }),
  ),
};

export default Atoms;
