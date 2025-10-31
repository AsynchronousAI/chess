import { Color, FILES, Piece, RANKS, Square } from "shared/board";
import { BitBoard } from "./bitboard";

/* Utility functions */
function isOnBoard(index: number): boolean {
  return index >= 0 && index < 64;
}
function onEdge(n: Square): boolean {
  return n < 8 || n >= 56 || n % 8 === 0 || n % 8 === 7;
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
    [2, 1],
    [2, -1],
    [-2, 1],
    [-2, -1],
    [1, 2],
    [1, -2],
    [-1, 2],
    [-1, -2],
  ],
  [Piece.king]: [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
    [1, 1],
    [-1, 1],
    [1, -1],
    [-1, -1],
  ],
};
const CUSTOM_DIRECTIONS: Partial<
  Record<
    Piece,
    (piece: [Piece, Color], pos: number, board: BitBoard) => Square[]
  >
> = {
  [Piece.pawn]: (piece, pos, board) => {
    const moves: Square[] = [];

    const dir = piece[1] === 0 ? 1 : -1;
    const startRank = piece[1] === 0 ? 1 : 6;

    // Forward move
    const oneStep = pos + dir * 8;
    const onBoard = isOnBoard(oneStep);
    if (onBoard) {
      if (!BitBoard.hasPiece(board, oneStep)) {
        moves.push(oneStep);

        // Two steps from start
        const twoStep = oneStep + dir * 8;
        const isStarting = pos >= startRank * 8 && pos < startRank * 8 + 8;
        if (isStarting && !BitBoard.hasPiece(board, twoStep)) {
          moves.push(twoStep);
        }
      }

      // Captures
      for (const dx of [9, 7]) {
        const newPos = pos + dx * dir;
        if (!isOnBoard(newPos)) continue;
        const target = BitBoard.getPiece(board, newPos);
        if (target[0] !== 0 && target[1] !== piece[1]) {
          moves.push(newPos);
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
  checks: boolean = true,
): Square[] {
  const piece = BitBoard.getPiece(board, from);
  if (!piece) return [];

  let moves: Square[] = [];

  let kingPosition =
    checks && BitBoard.findPiece(board, Piece.king, BitBoard.getTurn(board))[0];

  const pushMove = (newPos: Square) => {
    // check for checks
    if (kingPosition) {
      const newBoard = BitBoard.branch(board);
      BitBoard.movePiece(newBoard, from, newPos);

      // king moved?
      let localKingPos = kingPosition;
      if (from === kingPosition) {
        localKingPos = newPos;
      }

      for (const [_, followingMoveEnd] of GetAllLegalMoves(
        newBoard,
        1 - piece[1],
        false,
      )) {
        if (followingMoveEnd === localKingPos) {
          return;
        }
      }
    }
    moves.push(newPos);
  };

  if (CUSTOM_DIRECTIONS[piece[0]]) {
    const customMoves = CUSTOM_DIRECTIONS[piece[0]]!(piece, from, board);
    for (const newPos of customMoves) {
      pushMove(newPos);
    }
  } else if (FIXED_DIRECTIONS[piece[0]] !== undefined) {
    const [xOrigin, yOrigin] = [from % 8, math.floor(from / 8)];
    for (const [x, y] of FIXED_DIRECTIONS[piece[0]]!) {
      const newPosition = from + x + y * 8;

      const newX = xOrigin + x;
      const newY = yOrigin + y;
      if (newX < 0 || newX > 7 || newY < 0 || newY > 7) continue;

      const target = BitBoard.getPiece(board, newPosition);

      if (target[0] === Piece.none || target[1] !== piece[1]) {
        pushMove(newPosition);
      }
    }
  } else if (SLIDE_DIRECTIONS[piece[0]] !== undefined) {
    const [fx, fy] = [from % 8, math.floor(from / 8)];
    for (const [dx, dy] of SLIDE_DIRECTIONS[piece[0]]!) {
      let x = fx + dx;
      let y = fy + dy;
      while (x >= 0 && y >= 0 && x < 8 && y < 8) {
        const location = BitBoard.getSquareIndex(x, y);
        const target = BitBoard.getPiece(board, location);
        if (target[0] === 0) {
          pushMove(location);
        } else {
          if (target[1] !== piece[1]) {
            pushMove(location);
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
      if (to === kingPosition) {
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
