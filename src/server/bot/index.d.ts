import { BitBoard, Move } from "shared/engine/bitboard";

export interface BestMoveResponse {
  eval: number;
  mate: number;
  depth: number;
  move?: Move;
}

export function GetBestMoveLocal(board: BitBoard): BestMoveResponse;
