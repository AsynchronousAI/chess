import { BitBoard } from "../shared/engine/bitboard";
import { HttpService } from "@rbxts/services";
import { BestMoveResponse, GetBestMoveLocal } from "./bot";

function bestMoveAPI(board: BitBoard): BestMoveResponse {
  const fen = BitBoard.to_fen(board);
  const turn = board.side_to_move;
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
    eval:
      bestMove.eval !== undefined
        ? turn === 1
          ? bestMove.eval
          : -bestMove.eval
        : 0,
    mate:
      bestMove.mate !== undefined
        ? turn === 1
          ? bestMove.mate
          : -bestMove.mate
        : 0,
    depth: bestMove.depth ?? 0,
    /* TODO: new notation parer for API */
    //move: bestMove.bestmove ? Notation.parseLan(bestMove.bestmove) : undefined,
  };
}
export function GetBestMove(board: BitBoard, api: boolean) {
  if (api) return bestMoveAPI(board);
  else return GetBestMoveLocal(board);
}
