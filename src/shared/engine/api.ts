import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";
import { FEN } from "./fen";

export function GetBestMoveAPI(board: BitBoard) {
  const fen = FEN.toFEN(board);
  const bestMove = HttpService.JSONDecode(
    HttpService.PostAsync(
      "https://chess-api.com/v1",
      HttpService.JSONEncode({
        fen,
        depth: 12,
      }),
    ),
  ) as unknown as {
    lan: string;
    text: string;
    eval: number;
    mate: number;
  };

  return {
    ...bestMove,
    move: bestMove.lan ? Notation.parseLan(bestMove.lan) : undefined,
  };
}
