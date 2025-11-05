import { Object } from "@rbxts/luau-polyfill";
import { Color, Piece, Square } from "shared/board";
import { Notation } from "./notation";
import { BitBoard } from "./bitboard";

type PGNHeader = {
  event?: string;
  site?: string;
  date?: string;
  round?: string;
  white?: string;
  black?: string;
  result?: string;
};

export class PGN {
  headers: PGNHeader;
  moves: {
    board: BitBoard;
    to: Square;
    promotion?: Piece;
    result: string;
    moveStr: string;
  }[];

  constructor(headers: PGNHeader = {}) {
    this.headers = { ...headers, result: headers.result || "*" };
    this.moves = [];
  }

  move(board: BitBoard, to: Square, promotion?: Piece, result: string = "") {
    let moveStr = Notation.encodeSquareFull(board, to, promotion);
    if (result === "checkmate") {
      this.headers.result = "1-0";
      moveStr += "#"; /* # means mate! */
    } else if (result === "stalemate" || result === "draw") {
      this.headers.result = "1/2-1/2";
    }

    this.moves.push({
      board,
      to,
      promotion,
      result,
      moveStr,
    });

    return this;
  }

  toString(): string {
    const headersStr = Object.entries(this.headers)
      .map(([key, value]) => `[${key} "${value || ""}"]`)
      .join("\n");

    let movesStr = "";
    let moves = 0;
    for (const move of this.moves) {
      const isWhite = (this.moves.indexOf(move) >> 1) % 2 === 0;
      if (isWhite) {
        movesStr += `${++moves}. ${move.moveStr} `;
      } else {
        movesStr += `${move.moveStr} `;
      }
    }

    return `${headersStr}\n\n${movesStr} ${this.headers.result}`;
  }
}
