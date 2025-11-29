import { Piece, Square } from "shared/board";

export namespace Move {
  export function create(
    from: Square,
    to: Square,
    piece_type: Piece,
    captured?: boolean,
    promotion?: Piece,
    en_passant?: boolean,
    castling?: boolean,
    kingside?: boolean,
    value?: number,
  ): number;

  export function getFrom(move: number): Square;
  export function getTo(move: number): Square;
  export function getPieceType(move: number): Piece;
  export function getCaptured(move: number): Piece;
  export function getPromotion(move: number): Piece;
  export function getEnPassant(move: number): boolean;
  export function getCastling(move: number): LuaTuple<[boolean, boolean]>;
  export function getValue(move: number): number;

  export function setFrom(move: number, from: Square): number;
  export function setTo(move: number, to: Square): number;
  export function setPieceType(move: number, piece_type: Piece): number;
  export function setCaptured(move: number, captured: boolean): number;
  export function setPromotion(move: number, promotion: Piece): number;
  export function setEnPassant(move: number, en_passant: boolean): number;
  export function setCastling(
    move: number,
    castling: boolean,
    kingside: boolean,
  ): number;
  export function setValue(move: number, value: number): number;

  export function toTable(move: number): {
    from: Square;
    to: Square;
    piece_type: Piece;
    captured?: boolean;
    promotion?: Piece;
    en_passant?: boolean;
    castling?: boolean;
    kingside?: boolean;
    value: number;
  };
  export function toString(move: number): string;
}
