import { Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";

export function GetBestMoveAPI(board: BitBoard) {
  const fen = BitBoard.toFEN(board);
  const bestMove = HttpService.JSONDecode(
    HttpService.PostAsync(
      "https://chess-api.com/v1",
      HttpService.JSONEncode({
        fen,
        depth: 2,
      }),
    ),
  ) as unknown as {
    lan: string;
    text: string;
    eval: number;
  };

  return {
    move: bestMove.lan ? Notation.parseLan(bestMove.lan) : undefined,
    eval: bestMove.eval,
  };
}
