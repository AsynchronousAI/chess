import { Color, Square } from "shared/board";
import { BitBoard } from "./bitboard";
import { GetAllLegalMoves } from "./legalMoves";
import { EvaluateBoard } from "./eval";

function Minimax(
  board: BitBoard,
  depth: number,
  alpha: number,
  beta: number,
  isMaximizing: boolean,
  transposition: Record<string, number>,
): number {
  const moves = GetAllLegalMoves(board, BitBoard.getTurn(board), false);
  const hash = BitBoard.hash(board);

  if (transposition[hash] !== undefined) {
    return transposition[hash];
  }

  if (depth === 0 || moves.size() === 0) {
    return EvaluateBoard(board);
  }

  let value = isMaximizing ? -math.huge : math.huge;

  for (const move of moves) {
    const branch = BitBoard.branch(board);
    BitBoard.movePiece(branch, move[0], move[1]);

    const score = Minimax(
      branch,
      depth - 1,
      alpha,
      beta,
      !isMaximizing,
      transposition,
    );

    if (isMaximizing) {
      value = math.max(value, score);
      alpha = math.max(alpha, value);
      if (beta <= alpha) break; // β cut-off
    } else {
      value = math.min(value, score);
      beta = math.min(beta, value);
      if (beta <= alpha) break; // α cut-off
    }
  }

  transposition[hash] = value;
  return value;
}

export = (
  board: BitBoard,
  depth: number,
  turn: Color,
  move: [Square, Square],
  moves: Record<number, number>,
  index: number,
  transposition: Record<string, number>,
) => {
  const branch = BitBoard.branch(board);
  BitBoard.movePiece(branch, move[0], move[1]);

  const score = Minimax(
    branch,
    depth - 1,
    -math.huge,
    math.huge,
    turn === 0,
    transposition,
  );
  moves[index] = score;
};
