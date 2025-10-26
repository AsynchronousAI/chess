import { Color, FILES, Piece, RANKS, Square } from "shared/board";
import { BitBoard } from "./bitboard";

/* Utility functions */
function isOnBoard(file: number, rank: number): boolean {
  return file >= 0 && file < FILES.size() && rank >= 0 && rank < RANKS.size();
}

/* Direction Rules */
const SLIDE_DIRECTIONS: Partial<Record<Piece, [number, number][]>> = {
  [Piece.rook]: [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ],
  [Piece.bishop]: [
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ],
  [Piece.queen]: [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ],
};
const FIXED_DIRECTIONS: Partial<Record<Piece, [number, number][]>> = {
  [Piece.knight]: [
    [1, 2],
    [2, 1],
    [-1, 2],
    [-2, 1],
    [1, -2],
    [2, -1],
    [-1, -2],
    [-2, -1],
  ],
};
const CUSTOM_DIRECTIONS: Partial<
  Record<
    Piece,
    (piece: [Piece, Color], fy: number, fx: number, board: BitBoard) => Square[]
  >
> = {
  [Piece.pawn]: (piece, fy, fx, board) => {
    const moves: Square[] = [];

    const dir = piece[1] === 0 ? 1 : -1;
    const startRank = piece[1] === 0 ? 1 : 6;

    // Forward move
    const oneStep = fy + dir;
    if (isOnBoard(fx, oneStep) && !board.hasPiece(fx, oneStep)) {
      moves.push([fx, oneStep]);

      // Two steps from start
      const twoStep = fy + dir * 2;
      if (fy === startRank && !board.hasPiece(fx, twoStep)) {
        moves.push([fx, twoStep]);
      }
    }

    // Captures
    for (const dx of [-1, 1]) {
      const nx = fx + dx;
      if (nx < 0 || nx > 7) continue;
      const captureSquare: Square = [nx, fy + dir];
      const target = board.getPiece(nx, fy + dir);
      if (target[0] !== 0 && target[1] !== piece[1]) {
        moves.push(captureSquare);
      }
    }

    return moves;
  },
  [Piece.king]: (piece, fy, fx, board) => {
    const moves: Square[] = [];

    /* base movement */
    for (const dx of [-1, 0, 1]) {
      for (const dy of [-1, 0, 1]) {
        const nx = fx + dx;
        const ny = fy + dy;
        if (!isOnBoard(nx, ny)) continue;
        const target = board.getPiece(nx, ny);
        if (target[0] === 0 || target[1] !== piece[1]) {
          moves.push([nx, ny]);
        }
      }
    }

    return moves;
  },
};

/* Export */
export default function GetLegalMoves(
  board: BitBoard,
  from: Square,
  checkForColor?: Color,
): Square[] {
  const piece = board.getPiece(from[0], from[1]);
  if (!piece) return [];

  const [fx, fy] = from;
  let moves: Square[] = [];

  let kingPosition = undefined;
  if (checkForColor) {
    for (const [location, [piece, color]] of board.getAllPieces()) {
      if (piece === Piece.king && color === checkForColor) {
        kingPosition = location;
      }
    }
  }

  const pushMove = (x: number, y: number) => {
    // check for checks
    if (kingPosition) {
      const newBoard = board.branch();
      newBoard.movePiece(from, [x, y]);

      let localKingPos = kingPosition;
      if (from[0] === localKingPos[0] && from[1] === localKingPos[1]) {
        /* moving the king, track this position */
        localKingPos = [x, y];
      }

      for (const [followingMoveStart, followingMoveEnd] of GetAllLegalMoves(
        newBoard,
        1 - piece[1],
      )) {
        /* check if they can take the king */
        if (
          followingMoveEnd[0] === localKingPos[0] &&
          followingMoveEnd[1] === localKingPos[1]
        ) {
          return;
        }
      }
    }
    moves.push([x, y]);
  };

  if (CUSTOM_DIRECTIONS[piece[0]]) {
    const customMoves = CUSTOM_DIRECTIONS[piece[0]]!(piece, fy, fx, board);
    for (const [x, y] of customMoves) {
      pushMove(x, y);
    }
  } else if (FIXED_DIRECTIONS[piece[0]] !== undefined) {
    for (const [dx, dy] of FIXED_DIRECTIONS[piece[0]]!) {
      const x = fx + dx;
      const y = fy + dy;

      if (x < 0 || y < 0 || x >= 8 || y >= 8) continue;
      const target = board.getPiece(x, y);

      if (target[0] === 0 || target[1] !== piece[1]) {
        pushMove(x, y);
      }
    }
  } else if (SLIDE_DIRECTIONS[piece[0]] !== undefined) {
    for (const [dx, dy] of SLIDE_DIRECTIONS[piece[0]]!) {
      let x = fx + dx;
      let y = fy + dy;
      while (x >= 0 && y >= 0 && x < 8 && y < 8) {
        const target = board.getPiece(x, y);
        if (target[0] === 0) {
          pushMove(x, y);
        } else {
          if (target[1] !== piece[1]) {
            pushMove(x, y);
          }
          break;
        }
        x += dx;
        y += dy;
      }
    }
  }

  return moves;
}
export function GetAllLegalMoves(
  board: BitBoard,
  turn: Color,
): [Square, Square][] {
  const moves: [Square, Square][] = [];
  for (const [location, [piece, color]] of board.getAllPieces()) {
    if (color !== turn) continue;
    for (const nextLocation of GetLegalMoves(board, location)) {
      moves.push([location, nextLocation]);
    }
  }

  return moves;
}
