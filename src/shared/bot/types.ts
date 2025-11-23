import { Piece, Square } from "shared/board";

export interface BestMoveResponse {
  eval: number;
  mate: number;
  depth: number;
  move?: [Square, Square, Piece | undefined];
}
