import { Object, String } from "@rbxts/luau-polyfill";
import { Color, Piece, Square } from "shared/board";
import { Notation } from "./notation";
import { BitBoard } from "./bitboard";

export class PGN {
  private headers: {
    [key: string]: string;
  } = {};
  private moves: {
    board: BitBoard;
    to: Square;
    promotion?: Piece;
    moveStr: string;
  }[] = [];

  public move(board: BitBoard, to: Square, promotion?: Piece) {
    let moveStr = Notation.encodeSquareFull(board, to, promotion);

    this.moves.push({
      board,
      to,
      promotion,
      moveStr,
    });

    return this;
  }

  public compile(result: string = "", headers: boolean = true): string {
    /* Endgame indicator */
    if (result === "checkmate") {
      this.headers.result = "1-0"; /* TODO: Let black win */
    } else if (result === "stalemate" || result === "draw") {
      this.headers.result = "1/2-1/2";
    } else if (result !== "none") {
      this.headers.result = "*";
    }

    /* Combine moves */
    let movesStr = "";
    let moves = 0;
    for (const [index, move] of Object.entries(this.moves)) {
      const isWhite = (index - 1) % 2 === 0;
      if (isWhite) {
        movesStr += `${++moves}. ${move.moveStr} `;
      } else {
        movesStr += `${move.moveStr} `;
      }
    }
    movesStr = String.trimEnd(movesStr);

    /* Return with or without headers */
    if (headers) {
      const headersStr = Object.entries(this.headers)
        .map(([key, value]) => `[${key} "${value || ""}"]`)
        .join("\n");

      return `${headersStr}\n\n${movesStr} ${this.headers.result ?? ""}`;
    } else {
      return movesStr;
    }
  }
}
