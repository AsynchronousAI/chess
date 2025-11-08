import { Color, Piece } from "shared/board";
import { BitBoard, CASTLE_INDEX, EN_PASSANT } from "./bitboard";
import { Notation } from "./notation";

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

export namespace FEN {
  export function fromFEN(fen: string) {
    /* todo: read turn */
    const board = BitBoard.create();
    let file = 0;
    let rank = 7;

    const [
      pieces,
      activeColor,
      castling,
      enPassant,
      halfMoveClock,
      fullMoveClock,
    ] = fen.split(" ");

    /* Load pieces */
    for (const char of pieces.split("")) {
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
        BitBoard.setPiece(
          board,
          BitBoard.getSquareIndex(file, rank),
          pieceType,
          color,
        );
        file++;
      }
    }

    /* Load castling */
    for (const char of castling.split("")) {
      switch (char) {
        case "K":
          buffer.writeu8(board, CASTLE_INDEX[Color.white][1], 1);
          break;
        case "Q":
          buffer.writeu8(board, CASTLE_INDEX[Color.white][0], 1);
          break;
        case "k":
          buffer.writeu8(board, CASTLE_INDEX[Color.black][1], 1);
          break;
        case "q":
          buffer.writeu8(board, CASTLE_INDEX[Color.black][0], 1);
          break;
      }
    }

    /* Load en passant */
    if (enPassant === "-") {
      buffer.writeu8(board, EN_PASSANT, 0);
    } else {
      buffer.writeu8(board, EN_PASSANT, Notation.parseSquare(enPassant));
    }

    return board;
  }
  export function toFEN(board: BitBoard): string {
    let fen = "";
    let castling = "";
    let empty = 0;

    /* Pieces */
    for (let rank = 7; rank >= 0; rank--) {
      for (let file = 0; file < 8; file++) {
        const [pieceType, color] = BitBoard.getPiece(
          board,
          BitBoard.getSquareIndex(file, rank),
        );
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

    /* Castling */
    if (buffer.readu8(board, CASTLE_INDEX[Color.white][1])) castling += "K";
    if (buffer.readu8(board, CASTLE_INDEX[Color.white][0])) castling += "Q";
    if (buffer.readu8(board, CASTLE_INDEX[Color.black][1])) castling += "k";
    if (buffer.readu8(board, CASTLE_INDEX[Color.black][0])) castling += "q";
    if (castling === "") castling = "-";

    /* En passant */
    let enPassant = "-";
    let enPassantBit = buffer.readu8(board, EN_PASSANT);
    if (enPassantBit === 0) {
      enPassant = "-";
    } else {
      enPassant = Notation.encodeSquare(enPassantBit);
    }

    return `${fen} ${BitBoard.getTurn(board) === 0 ? "w" : "b"} ${castling} ${enPassant} 0 2`;
  }
}

export const DefaultBoard = FEN.fromFEN(
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
);
