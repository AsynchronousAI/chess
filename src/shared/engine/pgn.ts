import { Object } from "@rbxts/luau-polyfill";
import { Square } from "shared/board";
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
  moves: string[];

  constructor(headers: PGNHeader = {}) {
    this.headers = { ...headers, result: headers.result || "*" };
    this.moves = [];
  }

  move(board: BitBoard, to: Square, result: string = "") {
    let moveStr = `${Notation.encodeSquareFull(board, to)}`;
    if (result === "checkmate") {
      this.headers.result = "1-0";
      moveStr += "#";
    } else if (result === "stalemate" || result === "draw") {
      this.headers.result = "1/2-1/2";
    }

    const turn = math.floor(this.moves.size() / 2) + 1;
    if (this.moves.size() % 2 === 0) {
      this.moves.push(`${turn}. ${moveStr}`);
    } else {
      this.moves.push(moveStr);
    }

    if (result !== "") print(this.toString());

    return this;
  }

  toString(): string {
    const headersStr = Object.entries(this.headers)
      .map(([key, value]) => `[${key} "${value || ""}"]`)
      .join("\n");

    const movesStr = this.moves.join(" ");

    return `${headersStr}\n\n${movesStr} ${this.headers.result}`;
  }
}
