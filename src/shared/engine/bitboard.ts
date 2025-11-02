import { Color, Piece, Square } from "shared/board";

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

const CURRENT_TURN = 8 * 64 + 1;
const CASTLE_WQ = 8 * 64 + 2;
const CASTLE_WK = 8 * 64 + 3;
const CASTLE_BQ = 8 * 64 + 4;
const CASTLE_BK = 8 * 64 + 5;

export namespace BitBoard {
  export const create = (fen?: string) => {
    const board = buffer.create(8 * 64 + 6) as BitBoard;
    // Layout
    // ([piece id][color])*64 [currentTurn] [white queenside castle] [white kingside castle] [black queenside castle] [black kingside castle]

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
  }
  export function breakCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ) {
    if (color === 0) {
      if (queenSide) {
        buffer.writeu8(board, CASTLE_WQ, 0);
      } else {
        buffer.writeu8(board, CASTLE_WK, 0);
      }
    } else {
      if (queenSide) {
        buffer.writeu8(board, CASTLE_BQ, 0);
      } else {
        buffer.writeu8(board, CASTLE_BK, 0);
      }
    }
  }
  export function getCastlingRights(
    board: BitBoard,
    color: Color,
    queenSide: boolean,
  ): boolean {
    if (color === 0) {
      if (queenSide) {
        return buffer.readu8(board, CASTLE_WQ) === 1;
      } else {
        return buffer.readu8(board, CASTLE_WK) === 1;
      }
    } else {
      if (queenSide) {
        return buffer.readu8(board, CASTLE_BQ) === 1;
      } else {
        return buffer.readu8(board, CASTLE_BK) === 1;
      }
    }
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

  export function hash(board: BitBoard): string {
    return buffer.tostring(board);
  }

  /* FEN */
  export function fromFEN(board: BitBoard, fen: string) {
    /* todo: read turn, castle, en passant */
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
        setPiece(board, getSquareIndex(file, rank), pieceType, color);
        file++;
      }
    }

    /* Load castling */
    for (const char of castling.split("")) {
      switch (char) {
        case "K":
          buffer.writeu8(board, CASTLE_WK, 1);
          break;
        case "Q":
          buffer.writeu8(board, CASTLE_WQ, 1);
          break;
        case "k":
          buffer.writeu8(board, CASTLE_BK, 1);
          break;
        case "q":
          buffer.writeu8(board, CASTLE_BQ, 1);
          break;
      }
    }
  }
  export function toFEN(board: BitBoard): string {
    let fen = "";
    let castling = "";
    let empty = 0;

    /* Pieces */
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

    /* Castling */
    if (buffer.readu8(board, CASTLE_WK)) castling += "K";
    if (buffer.readu8(board, CASTLE_WQ)) castling += "Q";
    if (buffer.readu8(board, CASTLE_BK)) castling += "k";
    if (buffer.readu8(board, CASTLE_BQ)) castling += "q";
    if (castling === "") castling = "-";

    return `${fen} ${getTurn(board) === 0 ? "w" : "b"} ${castling} - 0 2`;
  }
}
