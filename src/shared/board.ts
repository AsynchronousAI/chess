/** Types */
export const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"] as const;
export const RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"] as const;
export type Square = number;

export enum Piece {
  none = 0,
  rook = 1,
  knight = 2,
  bishop = 3,
  queen = 4,
  king = 5,
  pawn = 6,
}
export enum Color {
  white = 0,
  black = 1,
}

export const DefaultFEN = "rkbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";


export function IsSquareBlack(i: number, j: number): boolean {
  return (i + j) % 2 === 0;
}
