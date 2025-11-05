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
const Promotion: Record<string, Piece> = {
  q: Piece.queen,
  r: Piece.rook,
  b: Piece.bishop,
  n: Piece.knight,
};

export namespace Notation {
  export function parseSquare(square: string): Square {
    const [file, rank] = square.split("");
    return BitBoard.getSquareIndex(
      FILES.indexOf(file as (typeof FILES)[number]),
      tonumber(rank)! - 1,
    );
  }
  export function encodeSquare(square: Square): string {
    const [file, rank] = BitBoard.separateSquareIndex(square);
    return FILES[file] + tostring(rank + 1);
  }
  export function encodeSquareFull(
    board: BitBoard,
    square: Square,
    promotion?: Piece,
    additional: string = "",
  ): string {
    const [piece] = BitBoard.getPiece(board, square);
    let result = Shorthand[piece] + additional + encodeSquare(square);
    if (promotion) {
      result += "=" + Shorthand[promotion];
    }
    return result;
  }
  export function parseLan(lan: string): [Square, Square, Piece | undefined] {
    const [from, to] = [lan.sub(0, 2), lan.sub(3, 4)];
    const promotion = lan.sub(5, 5);
    const piece = promotion ? Promotion[promotion] : undefined;
    return [parseSquare(from), parseSquare(to), piece];
  }
}
