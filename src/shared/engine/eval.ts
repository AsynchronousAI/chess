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

  let white = 0;
  let black = 0;

  for (const [square, [piece, color]] of pieces) {
    if (color === 0) {
      white += PieceValues[piece];
    } else {
      black += PieceValues[piece];
    }
  }

  return white - black;
}
