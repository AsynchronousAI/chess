import { Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService } from "@rbxts/services";
import { Notation } from "./notation";
import { GetAllLegalMoves } from "./legalMoves";
import { EvaluateBoard } from "./eval";
import Thread from "@rbxts/luau-thread-fixed";

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

const DEPTH = 4;

const [root, parts] = $getModuleTree("shared/engine/minimax");
const module = Thread.getModuleByTree(root, parts);

export function GetBestMove(
  board: BitBoard,
  depth = DEPTH,
): [Square, Square] | undefined {
  const turn = BitBoard.getTurn(board);
  const moves = GetAllLegalMoves(board, turn);
  if (moves.size() === 0) return;

  const branches = [];

  /* Add jobs */
  const sortedMoves = new SharedTable();
  for (const [index, move] of pairs(moves)) {
    branches.push(
      Thread.spawn(module, board, depth, turn, move, sortedMoves, index),
    );
  }

  /* Run in batch */
  const start = tick();
  Thread.join(branches);
  print(tick() - start);

  /* Get best move */
  const bestMoves = [];
  let bestScore = turn === 0 ? -math.huge : math.huge;

  let index = 0;
  for (const score of sortedMoves as unknown as number[]) {
    const move = moves[index];
    index++;
    if (turn === 0) {
      if (score > bestScore) {
        bestScore = score;
        bestMoves.clear();
      }
    } else {
      if (score < bestScore) {
        bestScore = score;
        bestMoves.clear();
      }
    }

    bestMoves.push(move);
  }

  return bestMoves[math.random(0, bestMoves.size() - 1)];
}
