import { Color, Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";

export function GetBestMove(board: BitBoard): [Square, Square] | undefined {
  const fen = BitBoard.toFEN(board);
  print(fen);
  const bestMove = HttpService.JSONDecode(
    HttpService.PostAsync(
      "https://chess-api.com/v1",
      HttpService.JSONEncode({
        fen,
      }),
    ),
  ) as unknown as {
    lan: string;
    text: string;
    eval: number;
  };
  print(bestMove);
  return bestMove.lan ? Notation.parseLan(bestMove.lan) : undefined;
}
