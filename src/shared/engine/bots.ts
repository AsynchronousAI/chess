import { Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { HttpService, RunService } from "@rbxts/services";
import { Notation } from "./notation";
import { GetAllLegalMoves } from "./legalMoves";
import Thread from "@rbxts/luau-thread-fixed";
import minimax from "./minimax";

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

let module: ModuleScript;
if (RunService.IsRunning()) {
  const [root, parts] = $getModuleTree("shared/engine/minimax");
  module = Thread.getModuleByTree(root, parts);
}

const transposition = new SharedTable();
export function GetBestMove(
  board: BitBoard,
  depth = DEPTH,
): [Square, Square] | undefined {
  const start = tick();
  const turn = BitBoard.getTurn(board);
  const moves = GetAllLegalMoves(board, turn);
  if (moves.size() === 0) return;

  const sortedMoves = new SharedTable();
  if (module) {
    /* Add jobs */
    const branches = [];
    for (const [index, move] of pairs(moves)) {
      branches.push(
        Thread.spawn(
          module,
          board,
          depth,
          turn,
          move,
          sortedMoves,
          index,
          transposition,
        ),
      );
    }

    /* Run in batch */
    Thread.join(branches);
  } else {
    for (const [index, move] of pairs(moves)) {
      minimax(
        board,
        depth,
        turn,
        move,
        sortedMoves as Record<number, number>,
        index,
        transposition as Record<string, number>,
      );
    }
  }

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
  print(bestScore);
  print(tick() - start);

  return bestMoves[math.random(0, bestMoves.size() - 1)];
}
