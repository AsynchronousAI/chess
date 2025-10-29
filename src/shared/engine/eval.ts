import { Color, Piece } from "shared/board";
import { BitBoard } from "./bitboard";
import { GetAllLegalMoves } from "./legalMoves";

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

  const whiteMoves = GetAllLegalMoves(board, Color.white, false);
  const blackMoves = GetAllLegalMoves(board, Color.black, false);

  /* mobility
  score += whiteMoves.size() * 0.1;
  score -= blackMoves.size() * 0.1;*/

  /* king exposure
  const whiteKingPosition = BitBoard.findPiece(
    board,
    Piece.king,
    Color.white,
  )[0];
  const blackKingPosition = BitBoard.findPiece(
    board,
    Piece.king,
    Color.black,
  )[0];

  const whiteKingDistance = whiteKingPosition
    ? math.sqrt(
        math.abs(whiteKingPosition[0] - 4) ** 2 +
          math.abs(whiteKingPosition[1] - 4) ** 2,
      )
    : 2;
  const blackKingDistance = blackKingPosition
    ? math.sqrt(
        math.abs(blackKingPosition[0] - 4) ** 2 +
          math.abs(blackKingPosition[1] - 4) ** 2,
      )
    : 2;

  score += math.max(0, 2 - whiteKingDistance);
  score -= math.max(0, 2 - blackKingDistance);
*/
  return score;
}
