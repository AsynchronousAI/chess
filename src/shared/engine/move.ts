import { FullMove } from "shared/network";
import { BitBoard } from "./bitboard";
import GetLegalMoves from "./legalMoves";

export function PerformMove(board: BitBoard, move: FullMove, flipTurn = true) {
  const legalMoves = GetLegalMoves(board, move[0], true);
  const found = legalMoves.find((m) => m[0] === move[1]);
  const turn = BitBoard.getTurn(board);

  if (!found) {
    return false;
  }

  /* Special moves, castling & en passant */
  const closure = found[1];
  closure?.(board);

  /* Board move */
  if (!move[2]) {
    BitBoard.movePiece(board, move[0], move[1]);
  } else {
    BitBoard.setPiece(board, move[0], 0, 0);
    BitBoard.setPiece(board, move[1], move[2], turn);
  }
  if (flipTurn) BitBoard.flipTurn(board);

  return true;
}
