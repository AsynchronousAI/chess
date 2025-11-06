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
    moveStr: string;
  }[];

  constructor(headers: PGNHeader = {}) {
    this.headers = { ...headers, result: headers.result || "*" };
    this.moves = [];
  }

  move(board: BitBoard, to: Square, promotion?: Piece, check: boolean = false) {
    let moveStr = Notation.encodeSquareFull(board, to, promotion);

    this.moves.push({
      board,
      to,
      promotion,
      moveStr,
    });

    return this;
  }

  compile(result: string): string {
    if (result === "checkmate") {
      this.headers.result = "1-0";
    } else if (result === "stalemate" || result === "draw") {
      this.headers.result = "1/2-1/2";
    }

    const headersStr = Object.entries(this.headers)
      .map(([key, value]) => `[${key} "${value || ""}"]`)
      .join("\n");

    let movesStr = "";
    let moves = 0;
    for (const [index, move] of Object.entries(this.moves)) {
      const isWhite = index % 2 === 0;
      if (index === this.moves.size() - 1 && result === "checkmate") {
        move.moveStr += "#";
      }
      if (isWhite) {
        movesStr += `${++moves}. ${move.moveStr} `;
      } else {
        movesStr += `${move.moveStr} `;
      }
    }

    return `${headersStr}\n\n${movesStr} ${this.headers.result}`;
  }
}
