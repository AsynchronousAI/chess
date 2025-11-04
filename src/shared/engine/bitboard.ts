import { Color, Piece, Square } from "shared/board";

export type BitBoard = buffer & { readonly brand: unique symbol };

const CURRENT_TURN = 8 * 64 + 1;
export const CASTLE_INDEX = {
  0: [8 * 64 + 2, 8 * 64 + 3],
  1: [8 * 64 + 4, 8 * 64 + 5],
};
/* CASTLE_INDEX[color][queenSide ? 0 : 1] */

export const EN_PASSANT = 8 * 64 + 6;
const SIZE = 8 * 64 + 7;
// TODO: Store pieces as u4 (pairs in a u8) and castles + current turn as 5 bits, and en passant as 6 bits.
// 519bits -> 267bits. (almost half!)
// ([piece id][color])*64 [currentTurn] [WQ castle] [WK castle] [BQ castle] [BK castle] [EnPassant]

export namespace BitBoard {
  export const create = () => buffer.create(SIZE) as BitBoard;

  /* internal */
  export function getSquareIndex(file: number, rank: number): number {
    // rank * 8 + file → (rank << 3) + file
    return (rank << 3) | file;
  }

  export function separateSquareIndex(loc: number): [number, number] {
    // file = loc % 8 → loc & 7
    // rank = Math.floor(loc / 8) → loc >> 3
    return [loc & 7, loc >> 3];
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
    const [originalPieceType] = binaryToPiece(buffer.readu8(board, to));

    const piece = buffer.readu8(board, from);
    buffer.writeu8(board, from, 0);
    buffer.writeu8(board, to, piece);

    /* castling rights */
    const [pieceType, color] = binaryToPiece(piece);

    /** moved king */
    if (pieceType === Piece.king) {
      BitBoard.breakCastlingRights(board, color, false);
      BitBoard.breakCastlingRights(board, color, true);
    }

    /** moved rook */
    if (pieceType === Piece.rook) {
      if (from === 0)
        breakCastlingRights(board, 0, true); // a1 rook
      else if (from === 7)
        breakCastlingRights(board, 0, false); // h1 rook
      else if (from === 56)
        breakCastlingRights(board, 1, true); // a8 rook
      else if (from === 63) breakCastlingRights(board, 1, false); // h8 rook
    }

    /** captured rook */
    if (originalPieceType === Piece.rook) {
      if (to === 0)
        breakCastlingRights(board, 0, true); // a1 rook
      else if (to === 7)
        breakCastlingRights(board, 0, false); // h1 rook
      else if (to === 56)
        breakCastlingRights(board, 1, true); // a8 rook
      else if (to === 63) breakCastlingRights(board, 1, false); // h8 rook
    }

    /* en passant */
    BitBoard.setEnPassant(board, undefined);
  }
  export function breakCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ) {
    buffer.writeu8(board, CASTLE_INDEX[color][queenSide ? 0 : 1], 0);
  }
  export function getCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ): boolean {
    return buffer.readu8(board, CASTLE_INDEX[color][queenSide ? 0 : 1]) === 1;
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
    return buffer.readu8(board, CURRENT_TURN);
  }
  export function flipTurn(board: BitBoard) {
    const currentTurn = getTurn(board);
    buffer.writeu8(board, CURRENT_TURN, 1 - currentTurn);
  }
  export function getEnPassant(board: BitBoard): Square | undefined {
    const index = buffer.readu8(board, EN_PASSANT);
    return index === 0 ? undefined : index;
  }
  export function setEnPassant(board: BitBoard, square: Square | undefined) {
    buffer.writeu8(board, EN_PASSANT, square ?? 0);
  }

  export function hash(board: BitBoard): string {
    return buffer.tostring(board);
  }
}
