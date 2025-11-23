import { BitBoard } from "shared/engine/bitboard";
import { Piece, Square } from "shared/board";

export interface BestMoveResponse {
  eval: number;
  mate: number;
  depth: number;
  move?: [Square, Square, Piece | undefined];
}

export function GetBestMoveLocal(board: BitBoard): BestMoveResponse;
