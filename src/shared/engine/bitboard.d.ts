//!native
//!optimize 2
import { Color, Piece, Square } from "shared/board";
export type BitBoard = buffer;

export const CASTLE_INDEX: Record<Color, [number, number]>;
export const EN_PASSANT: number;
export namespace BitBoard {
  export const create: () => BitBoard;

  /* internal */
  export function getSquareIndex(file: number, rank: number): number;

  export function separateSquareIndex(loc: number): [number, number];
  function binaryToPiece(piece: number): [Piece, Color];
  function getPieceBinary(pieceType: Piece, color: Color): number;

  /* base methods */
  export function setPiece(
    board: BitBoard,
    location: Square,
    pieceType: Piece,
    color: Color,
  ): void;
  export function getPiece(board: BitBoard, location: Square): [Piece, Color];
  export function hasPiece(board: BitBoard, location: Square): boolean;
  export function getAllPieces(board: BitBoard): [Square, [Piece, Color]][];
  export function movePiece(board: BitBoard, from: Square, to: Square): void;
  export function breakCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ): void;
  export function getCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ): boolean;
  export function branch(board: BitBoard): BitBoard;
  export function findPiece(
    board: BitBoard,
    piece: Piece,
    color: Color,
  ): Square[];
  export function getTurn(board: BitBoard): Color;
  export function flipTurn(board: BitBoard): void;
  export function getEnPassant(board: BitBoard): Square | undefined;
  export function setEnPassant(
    board: BitBoard,
    square: Square | undefined,
  ): void;
  export function hash(board: BitBoard): string;
}
