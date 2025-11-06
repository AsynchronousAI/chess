import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";
import { FEN } from "./fen";

export function GetBestMoveAPI(board: BitBoard) {
  const fen = FEN.toFEN(board);
  const bestMove = HttpService.JSONDecode(
    HttpService.PostAsync(
      "http://localhost:3000",
      HttpService.JSONEncode({
        fen,
      }),
    ),
  ) as unknown as {
    bestmove: string;
    eval: number;
    mate: number | undefined;
    depth: number;
  };

  return {
    eval: bestMove.eval ?? 0,
    mate: bestMove.mate,
    depth: bestMove.depth ?? 0,
    move: Notation.parseLan(bestMove.bestmove),
  };
}
