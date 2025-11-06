import { Piece, Square } from "shared/board";
import { Notation } from "./notation";
import { BitBoard } from "./bitboard";
import { String } from "@rbxts/luau-polyfill";

export type PGN = string[];
export namespace PGN {
  export function move(
    pgn: PGN,
    board: BitBoard,
    to: Square,
    promotion?: Piece,
  ): PGN {
    const moveStr = Notation.encodeSquareFull(board, to, promotion);
    pgn.push(moveStr);
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
      movesStr += `${pgn[i]} `;
    }

    return String.trimEnd(`${String.trimEnd(movesStr)} ${result ?? "*"}`);
  }

  export function create(): PGN {
    return [];
  }
}
