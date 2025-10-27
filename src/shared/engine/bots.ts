import { Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";
import { GetAllLegalMoves } from "./legalMoves";

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
  /* blunderfish */
  const moves = GetAllLegalMoves(board, BitBoard.getTurn(board));
  if (moves.size() === 0) return;

  const chosenMove = moves[math.random(0, moves.size() - 1)];
  print(
    Notation.encodeSquare(chosenMove[0]),
    "->",
    Notation.encodeSquare(chosenMove[1]),
  );
  return chosenMove;
}
