import { Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";
import { GetAllLegalMoves } from "./legalMoves";
import { EvaluateBoard } from "./eval";

export function GetBestMoveAPI(board: BitBoard): [Square, Square] | undefined {
  const fen = BitBoard.toFEN(board);
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
  return bestMove.lan ? Notation.parseLan(bestMove.lan) : undefined;
}
export function GetBestMove(board: BitBoard): [Square, Square] | undefined {
  const moves = GetAllLegalMoves(board, BitBoard.getTurn(board));
  if (moves.size() === 0) return;

  const evaluated = moves
    .map((move) => {
      const branch = BitBoard.branch(board);
      BitBoard.movePiece(branch, move[0], move[1]);
      return [move, EvaluateBoard(branch)] as [[Square, Square], number];
    })
    .sort(([, evalA], [, evalB]) => evalA < evalB);

  const bestMoves = evaluated.filter(([, evalue]) => evalue <= evaluated[0][1]);

  return bestMoves[math.random(0, bestMoves.size() - 1)][0];
}
