import { Color, IsSquareBlack, Piece, Square } from "shared/board";
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
        | [
            Square /* start square */,
            Square? /* end square, undefined means piece removed */,
            string? /* identifier used for SFX */,
          ]
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
    /* this just handles castling, movement is in FIXED_DIRECTIONS */
    const [, rank] = BitBoard.separateSquareIndex(pos);
    const moves: Move[] = [];

    const isLegalCastle = (mustBeEmpty: number[], mustNotAttack: number[]) => {
      const emptyCheck = mustBeEmpty.map((file) => file + rank * 8);
      const attackCheck = mustNotAttack.map((file) => file + rank * 8);

      for (const sq of emptyCheck) {
        if (BitBoard.hasPiece(board, sq)) {
          return false;
        }
      }
      for (const sq of attackCheck) {
        const attacker = IsSquareAttacked(board, sq, 1 - piece[1]);
        if (attacker !== Piece.none) {
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
          return [0 + rank * 8, 3 + rank * 8, "castle"];
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
          return [7 + rank * 8, 5 + rank * 8, "castle"];
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
): Piece {
  for (const [pos, [piece, color]] of BitBoard.getAllPieces(board)) {
    if (piece === Piece.none || color !== attacker) continue;

    const [x, y] = BitBoard.separateSquareIndex(pos);
    const [tx, ty] = BitBoard.separateSquareIndex(target);

    const dx = tx - x;
    const dy = ty - y;

    switch (piece) {
      case Piece.pawn: {
        const attackDir = color === Color.white ? 1 : -1; // white attacks +y, black attacks -y
        if (ty - y === attackDir && math.abs(tx - x) === 1) return piece;
        break;
      }
      case Piece.knight: {
        if (
          (math.abs(dx) === 2 && math.abs(dy) === 1) ||
          (math.abs(dx) === 1 && math.abs(dy) === 2)
        )
          return piece;
        break;
      }
      case Piece.king: {
        if (math.max(math.abs(dx), math.abs(dy)) === 1) return piece;
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

            if (cSquare === target) return piece;
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

  return Piece.none;
}

export default function GetLegalMoves(
  board: BitBoard,
  from: Square,
  checks: boolean = true,
  turn: Color = BitBoard.getTurn(board),
): Move[] {
  const piece = BitBoard.getPiece(board, from);
  if (!piece) {
    return [];
  }

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

      const attacker = IsSquareAttacked(newBoard, kingPosition, 1 - piece[1]);
      if (attacker !== Piece.none) {
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
    const [xOrigin, yOrigin] = BitBoard.separateSquareIndex(from);
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
    const [fx, fy] = BitBoard.separateSquareIndex(from);
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

function isInsufficientMaterial(board: any): boolean {
  const pieces: Partial<Record<Piece, number>> = {
    [Piece.king]: 0,
    [Piece.queen]: 0,
    [Piece.rook]: 0,
    [Piece.bishop]: 0,
    [Piece.knight]: 0,
    [Piece.pawn]: 0,
  };

  const bishopColors: boolean[] = []; // true = dark square, false = light square

  for (const [location, [piece, color]] of BitBoard.getAllPieces(board)) {
    pieces[piece] = (pieces[piece] || 0) + 1;

    if (piece === Piece.bishop) {
      bishopColors.push(
        IsSquareBlack(...BitBoard.separateSquareIndex(location)),
      );
    }
  }

  const bishops = pieces[Piece.bishop] || 0;
  const knights = pieces[Piece.knight] || 0;
  const rooks = pieces[Piece.rook] || 0;
  const queens = pieces[Piece.queen] || 0;
  const pawns = pieces[Piece.pawn] || 0;

  // Any pawns, rooks, or queens means sufficient material
  if (pawns > 0 || rooks > 0 || queens > 0) return false;

  // King vs King
  if (bishops === 0 && knights === 0) return true;

  // King + Bishop or Knight vs King
  if (bishops === 1 && knights === 0) return true;
  if (bishops === 0 && knights === 1) return true;

  // King + Bishop vs King + Bishop (same color bishops)
  if (bishops === 2 && knights === 0 && bishopColors[0] === bishopColors[1])
    return true;

  // King + Knight vs King + Knight
  if (knights === 2 && bishops === 0) return true;

  return false;
}

export function AnalyzeMates(
  board: BitBoard,
): "checkmate" | "stalemate" | "insufficent" | "" {
  const turn = BitBoard.getTurn(board);
  const legalMoves = GetAllLegalMoves(board, turn, true);

  /* In-sufficent material */
  if (isInsufficientMaterial(board)) return "insufficent";

  /* Based on legal moves */
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
