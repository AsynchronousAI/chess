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
    const onBoard = isOnBoard(fx, oneStep);
    if (onBoard) {
      if (!BitBoard.hasPiece(board, [fx, oneStep])) {
        moves.push([fx, oneStep]);

        // Two steps from start
        const twoStep = fy + dir * 2;
        if (fy === startRank && !BitBoard.hasPiece(board, [fx, twoStep])) {
          moves.push([fx, twoStep]);
        }
      }

      // Captures
      for (const dx of [-1, 1]) {
        const nx = fx + dx;
        if (nx < 0 || nx > 7) continue;
        const captureSquare: Square = [nx, fy + dir];
        const target = BitBoard.getPiece(board, captureSquare);
        if (target[0] !== 0 && target[1] !== piece[1]) {
          moves.push(captureSquare);
        }
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
        const target = BitBoard.getPiece(board, [nx, ny]);
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
  checks: boolean = false,
): Square[] {
  const piece = BitBoard.getPiece(board, from);
  if (!piece) return [];

  const [fx, fy] = from;
  let moves: Square[] = [];

  let kingPosition =
    checks && BitBoard.findPiece(board, Piece.king, BitBoard.getTurn(board))[0];

  const pushMove = (x: number, y: number) => {
    // check for checks
    if (kingPosition) {
      const newBoard = BitBoard.branch(board);
      BitBoard.movePiece(newBoard, from, [x, y]);

      // king moved?
      let localKingPos = kingPosition;
      if (from[0] === localKingPos[0] && from[1] === localKingPos[1]) {
        localKingPos = [x, y];
      }

      for (const [_, followingMoveEnd] of GetAllLegalMoves(
        newBoard,
        1 - piece[1],
        false,
      )) {
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
      const target = BitBoard.getPiece(board, [x, y]);

      if (target[0] === 0 || target[1] !== piece[1]) {
        pushMove(x, y);
      }
    }
  } else if (SLIDE_DIRECTIONS[piece[0]] !== undefined) {
    for (const [dx, dy] of SLIDE_DIRECTIONS[piece[0]]!) {
      let x = fx + dx;
      let y = fy + dy;
      while (x >= 0 && y >= 0 && x < 8 && y < 8) {
        const target = BitBoard.getPiece(board, [x, y]);
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
  checks: boolean = true,
): [Square, Square][] {
  const moves: [Square, Square][] = [];
  for (const [location, [piece, color]] of BitBoard.getAllPieces(board)) {
    if (color !== turn) continue;
    for (const nextLocation of GetLegalMoves(board, location, checks)) {
      moves.push([location, nextLocation]);
    }
  }

  return moves;
}
export function AnalyzeMates(board: BitBoard): "checkmate" | "stalemate" | "" {
  const turn = BitBoard.getTurn(board);
  const legalMoves = GetAllLegalMoves(board, turn, true);
  if (legalMoves.size() === 0) {
    const kingPosition = BitBoard.findPiece(board, Piece.king, turn)[0];

    const otherMoves = GetAllLegalMoves(board, 1 - turn, false);
    let inCheck = false;
    for (const [_, to] of otherMoves) {
      if (to[0] === kingPosition[0] && to[1] === kingPosition[1]) {
        inCheck = true;
        break;
      }
    }

    if (inCheck) {
      return "checkmate";
    } else {
      return "stalemate";
    }
  }
  return "";
}
