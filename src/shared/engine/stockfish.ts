import { Color, Square } from "shared/board";
import { BitBoard, parseLan } from "./bitboard";
import { HttpService } from "@rbxts/services";

export function GetBestMove(board: BitBoard): [Square, Square] | undefined {
  const fen = board.toFEN();
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
  print(bestMove.text);
  return bestMove.lan ? parseLan(bestMove.lan) : undefined;
}
