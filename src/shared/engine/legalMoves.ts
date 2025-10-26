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
export default function GetLegalMoves(board: BitBoard, from: Square): Square[] {
  const piece = board.getPiece(from[0], from[1]);
  if (!piece) return [];

  const [fx, fy] = from;
  let moves: Square[] = [];

  const addMove = (x: number, y: number) => {
    if (x < 0 || y < 0 || x >= 8 || y >= 8) return;
    const target = board.getPiece(x, y);

    if (target[0] === 0 || target[1] !== piece[1]) {
      moves.push([x, y]);
    }
  };

  if (CUSTOM_DIRECTIONS[piece[0]]) {
    const customMoves = CUSTOM_DIRECTIONS[piece[0]]!(piece, fy, fx, board);
    moves = [...moves, ...customMoves];
  } else if (FIXED_DIRECTIONS[piece[0]] !== undefined) {
    for (const [dx, dy] of FIXED_DIRECTIONS[piece[0]]!) {
      addMove(fx + dx, fy + dy);
    }
  } else if (SLIDE_DIRECTIONS[piece[0]] !== undefined) {
    for (const [dx, dy] of SLIDE_DIRECTIONS[piece[0]]!) {
      let x = fx + dx;
      let y = fy + dy;
      while (x >= 0 && y >= 0 && x < 8 && y < 8) {
        const target = board.getPiece(x, y);
        if (target[0] === 0) {
          moves.push([x, y]);
        } else {
          if (target[1] !== piece[1]) {
            moves.push([x, y]);
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
