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

let n = 0;
function Minimax(
  board: BitBoard,
  depth: number,
  isMaximizing: boolean,
): number {
  const moves = GetAllLegalMoves(board, BitBoard.getTurn(board));
  n++;

  if (depth === 0 || moves.size() === 0) {
    return EvaluateBoard(board);
  }

  let bestScore = isMaximizing ? -math.huge : math.huge;

  for (const move of moves) {
    const branch = BitBoard.branch(board);
    BitBoard.movePiece(branch, move[0], move[1]);

    const score = Minimax(branch, depth - 1, !isMaximizing);

    if (isMaximizing) {
      bestScore = math.max(bestScore, score);
    } else {
      bestScore = math.min(bestScore, score);
    }
  }

  return bestScore;
}

const DEPTH = 2;
export function GetBestMove(
  board: BitBoard,
  depth = DEPTH,
): [Square, Square] | undefined {
  const turn = BitBoard.getTurn(board);
  const moves = GetAllLegalMoves(board, turn);
  if (moves.size() === 0) return;

  let bestScore = turn === 0 ? -math.huge : math.huge;
  let bestMoves: [Square, Square][] = [];

  const start = tick();

  for (const move of moves) {
    const branch = BitBoard.branch(board);
    BitBoard.movePiece(branch, move[0], move[1]);

    const score = Minimax(branch, depth - 1, turn === 0);

    if (
      (turn === 0 && score > bestScore) ||
      (turn === 1 && score < bestScore)
    ) {
      bestScore = score;
      bestMoves = [move];
    } else if (score === bestScore) {
      bestMoves.push(move);
    }
    task.wait();
  }

  print(n, "boards", bestScore, "best score", tick() - start, "taken");
  n = 0;
  return bestMoves[math.floor(math.random() * bestMoves.size())];
}
