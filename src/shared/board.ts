/** Types */
export const FILES = ["a", "b", "c", "d", "e", "f", "g", "h"] as const;
export const RANKS = ["1", "2", "3", "4", "5", "6", "7", "8"] as const;
export type File = (typeof FILES)[number];
export type Rank = (typeof RANKS)[number];
export type Square = `${File}${Rank}`;

export type Piece = "rook" | "knight" | "bishop" | "queen" | "king" | "pawn";
export type Color = "white" | "black";
export type Board = Partial<Record<Square, { color: Color; type: Piece }>>;

export const DefaultBoard: Board = {
  // White pieces
  a1: { color: "white", type: "rook" },
  b1: { color: "white", type: "knight" },
  c1: { color: "white", type: "bishop" },
  d1: { color: "white", type: "queen" },
  e1: { color: "white", type: "king" },
  f1: { color: "white", type: "bishop" },
  g1: { color: "white", type: "knight" },
  h1: { color: "white", type: "rook" },
  a2: { color: "white", type: "pawn" },
  b2: { color: "white", type: "pawn" },
  c2: { color: "white", type: "pawn" },
  d2: { color: "white", type: "pawn" },
  e2: { color: "white", type: "pawn" },
  f2: { color: "white", type: "pawn" },
  g2: { color: "white", type: "pawn" },
  h2: { color: "white", type: "pawn" },

  // Black pieces
  a8: { color: "black", type: "rook" },
  b8: { color: "black", type: "knight" },
  c8: { color: "black", type: "bishop" },
  d8: { color: "black", type: "queen" },
  e8: { color: "black", type: "king" },
  f8: { color: "black", type: "bishop" },
  g8: { color: "black", type: "knight" },
  h8: { color: "black", type: "rook" },
  a7: { color: "black", type: "pawn" },
  b7: { color: "black", type: "pawn" },
  c7: { color: "black", type: "pawn" },
  d7: { color: "black", type: "pawn" },
  e7: { color: "black", type: "pawn" },
  f7: { color: "black", type: "pawn" },
  g7: { color: "black", type: "pawn" },
  h7: { color: "black", type: "pawn" },
};

export function IsSquareBlack(i: number, j: number): boolean {
  return (i + j) % 2 === 0;
}
