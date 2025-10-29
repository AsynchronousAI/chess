import { Color, Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { GetAllLegalMoves } from "./legalMoves";
import { EvaluateBoard } from "./eval";

function Minimax(board: BitBoard, depth: number, isMaximizing: boolean) {
  const moves = GetAllLegalMoves(board, BitBoard.getTurn(board));
  let bestScore = isMaximizing ? -math.huge : math.huge;

  if (depth === 0 || moves.size() === 0) {
    return EvaluateBoard(board);
  }

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

export = (
  board: BitBoard,
  depth: number,
  turn: Color,
  move: [Square, Square],
  moves: Record<number, number>,
  index: number,
) => {
  const branch = BitBoard.branch(board);
  BitBoard.movePiece(branch, move[0], move[1]);

  const score = Minimax(branch, depth - 1, turn === 0);
  moves[index] = score;
};
