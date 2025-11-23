import { Square } from "shared/board";
import { RunService } from "@rbxts/services";
import Thread from "@rbxts/luau-thread-fixed";
import minimax from "./minimax";
import { BitBoard } from "shared/engine/bitboard";
import { GetAllLegalMoves } from "shared/engine/legalMoves";
import { BestMoveResponse } from "./types";

const DEPTH = 4;

let module: ModuleScript;
if (RunService.IsRunning()) {
  const [root, parts] = $getModuleTree("shared/bot/minimax");
  module = Thread.getModuleByTree(root, parts);
}

const transposition = new SharedTable();
export function GetBestMoveLocal(
  board: BitBoard,
  depth = DEPTH,
): BestMoveResponse {
  const start = tick();
  const turn = BitBoard.getTurn(board);
  const moves = GetAllLegalMoves(board, turn);
  if (moves.size() === 0)
    return { eval: 0, move: undefined, mate: 0, depth: 0 };

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

  return {
    eval: 0,
    mate: 0,
    move: [...bestMoves[math.random(0, bestMoves.size() - 1)], undefined],
    depth: DEPTH,
  };
}
