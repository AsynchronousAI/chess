/** Types */
export const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"] as const;
export const RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"] as const;
export type Square = number;

// NOTE: if changing these also change in shared/engine/utils.luau

export enum Piece {
  none = -1,
  pawn = 0,
  knight = 1,
  bishop = 2,
  rook = 3,
  queen = 4,
  king = 5,
}

export enum Color {
  white = 0,
  black = 1,
}
export const PieceValues: Record<Piece, number> = {
  [Piece.none]: 0,
  [Piece.rook]: 5,
  [Piece.knight]: 3,
  [Piece.bishop]: 3,
  [Piece.queen]: 9,
  [Piece.king]: 100,
  [Piece.pawn]: 1,
};

export function IsSquareBlack(i: number, j: number): boolean {
  return (i + j) % 2 === 0;
}
export function GetPieceValues(pieces: Piece[]): number {
  return pieces.reduce((acc, piece) => acc + PieceValues[piece], 0);
}
export function IsPromotion(loc: Square, piece: Piece, color: Color) {
  return piece === Piece.pawn && (color === Color.white ? loc > 55 : loc < 8);
}
