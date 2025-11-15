import { Color, Piece, Square } from "shared/board";
import { Notation } from "./notation";
import { BitBoard } from "./bitboard";
import { String } from "@rbxts/luau-polyfill";

const Shorthand: Record<Piece, string> = {
  [Piece.bishop]: "B",
  [Piece.king]: "K",
  [Piece.knight]: "N",
  [Piece.pawn]: "",
  [Piece.none]: "",
  [Piece.queen]: "Q",
  [Piece.rook]: "R",
} as const;

export type PGN = {
  from: Square;
  to: Square;
  promotion?: Piece;
  piece: [Piece, Color];
  notation: string;
  state: BitBoard /* storing a state could be memory hogging, but with small memory footprint we should be good  */;
  moveType: string;
}[];

export namespace PGN {
  export function move(
    pgn: PGN,
    board: BitBoard,
    from: Square,
    to: Square,
    promotion?: Piece,
    capture?: boolean,
    moveType: string = "Move",
  ): PGN {
    const piece = BitBoard.getPiece(board, to);
    /* TODO: Castling, 'x' for takes, add piece shorthands,
        and explicitly tell from file + rank if another piece
        of same type can take */
    let notation = "";
    notation += Shorthand[piece[0]];
    if (capture) notation += "x";
    notation += Notation.encodeSquare(to);

    pgn.push({
      from,
      to,
      promotion,
      piece,
      notation,
      state: BitBoard.branch(board),
      moveType,
    });
    return pgn;
  }

  export function compile(
    pgn: PGN,
    result?: "1-0" | "0-1" | "1/2-1/2" | "*",
  ): string {
    let movesStr = "";
    let moveNum = 1;

    for (let i = 0; i < pgn.size(); i++) {
      if (i % 2 === 0) movesStr += `${moveNum++}. `;
      movesStr += `${pgn[i].notation} `;
    }

    return String.trimEnd(`${String.trimEnd(movesStr)} ${result ?? "*"}`);
  }

  export function create(): PGN {
    return [];
  }
}
