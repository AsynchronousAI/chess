//!native
//!optimize 2
import { BitBoard } from "./bitboard";
import GetLegalMoves, {
  GetAllLegalMoves,
  MoveExecutors,
  MoveType,
} from "./legalMoves";
import { Piece, Square } from "shared/board";

export function PerformMove(
  board: BitBoard,
  move: [Square, Square, Piece?, MoveType?],
  flipTurn = true,
) {
  const turn = BitBoard.getTurn(board);

  /* Special moves, castling & en passant */
  let moveType = move[3];
  if (moveType === undefined) {
    const legalMoves = GetLegalMoves(board, move[0], true);
    const found = legalMoves.find((m) => m[0] === move[1]);

    if (!found) {
      return false;
    }

    moveType = found[1];
  }

  const executor = MoveExecutors[moveType];
  if (executor) {
    executor(board, move[0], move[1]);
  }

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
