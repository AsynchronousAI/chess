import { FILES, Piece, Square } from "shared/board";
import { BitBoard } from "./bitboard";

const Shorthand: Record<Piece, string> = {
  [Piece.bishop]: "B",
  [Piece.king]: "K",
  [Piece.knight]: "N",
  [Piece.pawn]: "",
  [Piece.none]: "",
  [Piece.queen]: "Q",
  [Piece.rook]: "R",
} as const;
export namespace Notation {
  export function parseSquare(square: string): Square {
    const [file, rank] = square.split("");
    return BitBoard.getSquareIndex(
      FILES.indexOf(file as (typeof FILES)[number]),
      tonumber(rank)! - 1,
    );
  }
  export function encodeSquare(square: Square): string {
    const file = square % 8;
    const rank = math.floor(square / 8);
    return FILES[file] + tostring(rank + 1);
  }
  export function encodeSquareFull(
    board: BitBoard,
    square: Square,
    additional: string = "",
  ): string {
    const [piece] = BitBoard.getPiece(board, square);
    return Shorthand[piece] + additional + encodeSquare(square);
  }
  export function parseLan(lan: string): [Square, Square] {
    const [from, to] = [lan.sub(0, 2), lan.sub(3, 4)];
    return [parseSquare(from), parseSquare(to)];
  }
}
