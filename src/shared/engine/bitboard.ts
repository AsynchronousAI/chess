import { Color, FILES, Piece, Square } from "shared/board";

const fenLookup: Record<string, Piece> = {
  P: Piece.pawn,
  N: Piece.knight,
  B: Piece.bishop,
  R: Piece.rook,
  Q: Piece.queen,
  K: Piece.king,
};
const reverseFenLookup: Partial<Record<Piece, string>> = {
  [Piece.pawn]: "P",
  [Piece.knight]: "N",
  [Piece.bishop]: "B",
  [Piece.rook]: "R",
  [Piece.queen]: "Q",
  [Piece.king]: "K",
};

export type BitBoard = buffer & { readonly brand: unique symbol };
export namespace BitBoard {
  export const create = (fen?: string) => {
    const board = buffer.create(8 * 64 + 1) as BitBoard;
    // Layout
    // ([piece id][color])*64 [currentTurn]

    if (fen) fromFEN(board, fen);
    return board;
  };

  /* internal */
  export function getSquareIndex(file: number, rank: number): number {
    return rank * 8 + file;
  }
  function binaryToPiece(piece: number): [Piece, Color] {
    return [piece >> 1, piece & 1];
  }
  function getPieceBinary(pieceType: Piece, color: Color): number {
    return (pieceType << 1) | color;
  }

  /* base methods */
  export function setPiece(
    board: BitBoard,
    location: Square,
    pieceType: Piece,
    color: Color,
  ) {
    const piece = getPieceBinary(pieceType, color);
    buffer.writeu8(board, location, piece);
  }
  export function getPiece(board: BitBoard, location: Square): [Piece, Color] {
    return binaryToPiece(buffer.readu8(board, location));
  }
  export function hasPiece(board: BitBoard, location: Square): boolean {
    return buffer.readu8(board, location) !== 0;
  }
  export function getAllPieces(board: BitBoard): [Square, [Piece, Color]][] {
    const pieces: [Square, [Piece, Color]][] = [];
    for (let rank = 0; rank < 8; rank++) {
      let index = rank * 8;
      for (let file = 0; file < 8; file++, index++) {
        const piece = buffer.readu8(board, index);
        if (piece !== 0) {
          const [pieceType, color] = binaryToPiece(piece);
          pieces.push([getSquareIndex(file, rank), [pieceType, color]]);
        }
      }
    }
    return pieces;
  }
  export function movePiece(board: BitBoard, from: Square, to: Square) {
    const piece = buffer.readu8(board, from);
    buffer.writeu8(board, from, 0);
    buffer.writeu8(board, to, piece);
  }
  export function branch(board: BitBoard) {
    const branch = create();
    buffer.copy(branch, 0, board);
    return branch;
  }
  export function findPiece(
    board: BitBoard,
    piece: Piece,
    color: Color,
  ): Square[] {
    const squares: Square[] = [];
    for (const [location, [currentPiece, currentColor]] of getAllPieces(
      board,
    )) {
      if (piece === currentPiece && color === currentColor) {
        squares.push(location);
      }
    }

    return squares;
  }
  export function getTurn(board: BitBoard): Color {
    return buffer.readu8(board, buffer.len(board) - 1);
  }
  export function flipTurn(board: BitBoard) {
    const currentTurn = getTurn(board);
    buffer.writeu8(board, buffer.len(board) - 1, 1 - currentTurn);
  }

  export function hash(board: BitBoard): string {
    return buffer.tostring(board);
  }

  /* FEN */
  export function fromFEN(board: BitBoard, fen: string) {
    /* todo: read turn, castle, en passant */
    let file = 0;
    let rank = 7;

    for (const char of fen.split("")) {
      if (char === "/") {
        rank--;
        file = 0;
        continue;
      }
      if (char === " ") break; // unsupported

      const number = tonumber(char);
      if (number && number > 0 && number <= 8) {
        /* space */
        file += number;
      } else {
        const upper = string.upper(char);

        const pieceType = fenLookup[upper];
        const color = upper === char ? 0 : 1;
        setPiece(board, getSquareIndex(file, rank), pieceType, color);
        file++;
      }
    }
  }
  export function toFEN(board: BitBoard): string {
    let fen = "";
    let empty = 0;

    for (let rank = 7; rank >= 0; rank--) {
      for (let file = 0; file < 8; file++) {
        const [pieceType, color] = getPiece(board, getSquareIndex(file, rank));
        if ((pieceType as number) === 0) {
          empty++;
        } else {
          if (empty > 0) {
            fen += tostring(empty);
            empty = 0;
          }

          if (color === 0) {
            fen += reverseFenLookup[pieceType];
          } else {
            fen += string.lower(reverseFenLookup[pieceType]!);
          }
        }
      }
      if (empty > 0) {
        fen += tostring(empty);
        empty = 0;
      }
      if (rank > 0) fen += "/";
    }

    return `${fen} ${getTurn(board) === 0 ? "w" : "b"} KQkq - 0 2`;
  }
}
