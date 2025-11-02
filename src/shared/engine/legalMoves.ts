import { Color, Piece, Square } from "shared/board";
import { BitBoard } from "./bitboard";

/* Utility functions */
function isOnBoard(index: number): boolean {
  return index >= 0 && index < 64;
}

export type Move =
  | [Square]
  | [
      Square,
      (
        branch: BitBoard,
      ) =>
        | [Square, Square | undefined /* undefined means piece removed */]
        | void,
    ];

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
  Record<Piece, (piece: [Piece, Color], pos: number, board: BitBoard) => Move[]>
> = {
  [Piece.pawn]: (piece, pos, board) => {
    const moves: Move[] = [];

    const dir = piece[1] === 0 ? 1 : -1; // 1 for white, -1 for black
    const startRank = piece[1] === 0 ? 1 : 6;

    // Forward move
    const oneStep = pos + dir * 8;
    const onBoard = isOnBoard(oneStep);
    if (onBoard && !BitBoard.hasPiece(board, oneStep)) {
      moves.push([oneStep]);

      // Two steps from start
      const twoStep = oneStep + dir * 8;
      const isStarting = pos >= startRank * 8 && pos < startRank * 8 + 8;
      if (isStarting && !BitBoard.hasPiece(board, twoStep)) {
        moves.push([
          twoStep,
          (branch) => {
            BitBoard.setEnPassant(branch, oneStep);
          },
        ]);
      }
    }

    // Captures
    for (const dx of [9, 7]) {
      const newPos = pos + dx * dir;
      if (!isOnBoard(newPos)) continue;

      const target = BitBoard.getPiece(board, newPos);
      if (target[0] !== 0 && target[1] !== piece[1]) {
        // Normal capture
        moves.push([newPos]);
      } else {
        // En passant capture
        const enPassantSquare = BitBoard.getEnPassant(board);
        if (enPassantSquare === newPos) {
          moves.push([
            newPos,
            (branch) => {
              BitBoard.setPiece(branch, newPos - 8, Piece.none, 0);
              return [newPos - 8, undefined];
            },
          ]);
        }
      }
    }

    return moves;
  },

  [Piece.king]: (piece, pos, board) => {
    /* TODO: move rook also, and check for interruptions in between which include checks & pieces */
    /* this just handles castling, movement is in FIXED_DIRECTIONS */
    const rank = math.floor(pos / 8);
    const moves: Move[] = [];

    const isLegalCastle = (
      mustBeEmpty: number[],
      mustNotBeAttacked: number[],
    ) => {
      const emptyCheck = mustBeEmpty.map((file) => file + rank * 8);

      for (const sq of emptyCheck) {
        if (BitBoard.hasPiece(board, sq)) {
          return false;
        }
      }
      for (const sq of mustNotBeAttacked) {
        if (IsSquareAttacked(board, sq, 1 - piece[1])) {
          return false;
        }
      }

      return true;
    };
    if (
      BitBoard.getCastlingRights(board, piece[1], true) &&
      isLegalCastle([1, 2, 3], [2, 3, 4])
    ) {
      /* castle queenside, king goes to c file */
      moves.push([
        BitBoard.getSquareIndex(2, rank),
        (branch) => {
          BitBoard.movePiece(branch, 0 + rank * 8, 3 + rank * 8);
          return [0 + rank * 8, 3 + rank * 8];
        },
      ]);
    }
    if (
      BitBoard.getCastlingRights(board, piece[1], false) &&
      isLegalCastle([5, 6], [4, 5, 6])
    ) {
      moves.push([
        BitBoard.getSquareIndex(6, rank),
        (branch) => {
          BitBoard.movePiece(branch, 7 + rank * 8, 5 + rank * 8);
          return [7 + rank * 8, 5 + rank * 8];
        },
      ]);
    }
    return moves;
  },
};

/* Export */
export function IsSquareAttacked(
  board: BitBoard,
  target: Square,
  attacker: Color,
): boolean {
  for (const [pos, [piece, color]] of BitBoard.getAllPieces(board)) {
    if (color !== attacker) continue;

    const x = pos % 8;
    const y = math.floor(pos / 8);
    const tx = target % 8;
    const ty = math.floor(target / 8);

    const dx = tx - x;
    const dy = ty - y;

    switch (piece) {
      case Piece.pawn: {
        const dir = color === Color.white ? 1 : -1;
        if (dy === dir && math.abs(dx) === 1) return true;
        break;
      }
      case Piece.knight: {
        if (
          (math.abs(dx) === 2 && math.abs(dy) === 1) ||
          (math.abs(dx) === 1 && math.abs(dy) === 2)
        )
          return true;
        break;
      }
      case Piece.king: {
        if (math.max(math.abs(dx), math.abs(dy)) === 1) return true;
        break;
      }
      case Piece.rook:
      case Piece.bishop:
      case Piece.queen: {
        const directions = SLIDE_DIRECTIONS[piece]!;
        for (const [sx, sy] of directions) {
          let cx = x + sx;
          let cy = y + sy;
          while (cx >= 0 && cx < 8 && cy >= 0 && cy < 8) {
            const cSquare = BitBoard.getSquareIndex(cx, cy);
            const cPiece = BitBoard.getPiece(board, cSquare);

            if (cSquare === target) return true;
            if (cPiece[0] !== Piece.none) break;

            cx += sx;
            cy += sy;
          }
        }
        break;
      }
      default: {
        throw `Invalid piece: ${piece}`;
      }
    }
  }

  return false;
}

export default function GetLegalMoves(
  board: BitBoard,
  from: Square,
  checks: boolean = true,
  turn: Color = BitBoard.getTurn(board),
): Move[] {
  const piece = BitBoard.getPiece(board, from);
  if (!piece) return [];

  let moves: Move[] = [];

  let kingPosition = BitBoard.findPiece(board, Piece.king, turn)[0];
  const pushMove = (newPos: Move) => {
    if (checks) {
      /* branch + move */
      const newBoard = BitBoard.branch(board);
      const pos = newPos[0];
      BitBoard.movePiece(newBoard, from, pos);
      newPos[1]?.(newBoard);

      /* if the king moved then update it */
      if (piece[0] === Piece.king) {
        kingPosition = pos;
      }

      if (IsSquareAttacked(newBoard, kingPosition, 1 - piece[1])) {
        return;
      }
    }

    moves.push(newPos);
  };

  if (CUSTOM_DIRECTIONS[piece[0]]) {
    const customMoves = CUSTOM_DIRECTIONS[piece[0]]!(piece, from, board);
    for (const newPos of customMoves) {
      pushMove(newPos);
    }
  }
  if (FIXED_DIRECTIONS[piece[0]] !== undefined) {
    const [xOrigin, yOrigin] = [from % 8, math.floor(from / 8)];
    for (const [x, y] of FIXED_DIRECTIONS[piece[0]]!) {
      const newPosition = from + x + y * 8;

      const newX = xOrigin + x;
      const newY = yOrigin + y;
      if (newX < 0 || newX > 7 || newY < 0 || newY > 7) continue;

      const target = BitBoard.getPiece(board, newPosition);

      if (target[0] === Piece.none || target[1] !== piece[1]) {
        pushMove([newPosition]);
      }
    }
  }
  if (SLIDE_DIRECTIONS[piece[0]] !== undefined) {
    const [fx, fy] = [from % 8, math.floor(from / 8)];
    for (const [dx, dy] of SLIDE_DIRECTIONS[piece[0]]!) {
      let x = fx + dx;
      let y = fy + dy;
      while (x >= 0 && y >= 0 && x < 8 && y < 8) {
        const location = BitBoard.getSquareIndex(x, y);
        const target = BitBoard.getPiece(board, location);
        if (target[0] === 0) {
          pushMove([location]);
        } else {
          if (target[1] !== piece[1]) {
            pushMove([location]);
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
      moves.push([location, nextLocation[0]]);
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
