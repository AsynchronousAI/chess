import { Color, Piece } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";

const PieceValues: Record<Piece, number> = {
  [Piece.pawn]: 1,
  [Piece.knight]: 3,
  [Piece.bishop]: 3,
  [Piece.rook]: 5,
  [Piece.queen]: 9,
  [Piece.king]: 100,
  [Piece.none]: 0,
};

export function EvaluateBoard(board: BitBoard) {
  const pieces = BitBoard.getAllPieces(board);

  let score = 0;

  /* value */
  for (const [square, [piece, color]] of pieces) {
    if (color === Color.white) {
      score += PieceValues[piece];
    } else {
      score -= PieceValues[piece];
    }
  }

  return score;
}
