import { FILES, Piece, Square } from "shared/board";
import { BitBoard } from "./bitboard";

const Promotion: Record<string, Piece> = {
  q: Piece.queen,
  r: Piece.rook,
  b: Piece.bishop,
  n: Piece.knight,
};

export namespace Notation {
  export function parseSquare(square: string): Square {
    const [file, rank] = square.split("");
    return BitBoard.get_square_index(
      FILES.indexOf(file as (typeof FILES)[number]),
      tonumber(rank)! - 1,
    );
  }
  export function encodeSquare(square: Square): string {
    const [file, rank] = BitBoard.separate_square_index(square);
    return FILES[file] + tostring(rank + 1);
  }
  export function parseLan(lan: string): [Square, Square, Piece | undefined] {
    const [from, to] = [lan.sub(0, 2), lan.sub(3, 4)];
    const promotion = lan.sub(5, 5);
    const piece = promotion ? Promotion[promotion] : undefined;
    return [parseSquare(from), parseSquare(to), piece];
  }
}
