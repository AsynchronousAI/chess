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

export class BitBoard {
  public board = buffer.create(8 * 64); // 8 bits per square

  constructor(fen?: string) {
    if (fen) this.fromFEN(fen);
  }

  /* internal */
  private getSquareIndex(file: number, rank: number): number {
    return file * 8 + rank;
  }
  private getPieceBinary(pieceType: Piece, color: Color): number {
    return color | (pieceType << 3);
  }
  private binaryToPiece(piece: number): [Piece, Color] {
    const color = piece & 7;
    const pieceType = piece >> 3;
    return [pieceType, color];
  }

  /* base methods */
  public setPiece(file: number, rank: number, pieceType: Piece, color: Color) {
    const index = this.getSquareIndex(file, rank);
    const piece = this.getPieceBinary(pieceType, color);
    buffer.writeu8(this.board, index, piece);
  }
  public getPiece(file: number, rank: number): [Piece, Color] {
    const index = this.getSquareIndex(file, rank);
    return this.binaryToPiece(buffer.readu8(this.board, index));
  }
  public hasPiece(file: number, rank: number): boolean {
    const index = this.getSquareIndex(file, rank);
    return buffer.readu8(this.board, index) !== 0;
  }
  public getAllPieces(): [Square, [Piece, Color]][] {
    const pieces: [Square, [Piece, Color]][] = [];
    for (let rank = 0; rank < 8; rank++) {
      for (let file = 0; file < 8; file++) {
        const index = this.getSquareIndex(file, rank);
        const piece = buffer.readu8(this.board, index);
        if (piece !== 0) {
          const [pieceType, color] = this.binaryToPiece(piece);
          pieces.push([
            [file, rank],
            [pieceType, color],
          ]);
        }
      }
    }
    return pieces;
  }
  public movePiece(from: Square, to: Square) {
    const [fromFile, fromRank] = from;
    const [toFile, toRank] = to;

    const indexFrom = this.getSquareIndex(fromFile, fromRank);
    const indexTo = this.getSquareIndex(toFile, toRank);

    const piece = buffer.readu8(this.board, indexFrom);
    buffer.writeu8(this.board, indexFrom, 0);
    buffer.writeu8(this.board, indexTo, piece);
  }
  public branch() {
    const branch = new BitBoard();
    branch.board = buffer.create(buffer.len(this.board));
    buffer.copy(branch.board, 0, this.board);
    return branch;
  }

  /* FEN */
  public fromFEN(fen: string) {
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
        this.setPiece(file, rank, pieceType, color);
        file++;
      }
    }
  }
  public toFEN(): string {
    let fen = "";
    let empty = 0;

    for (let rank = 7; rank >= 0; rank--) {
      for (let file = 0; file < 8; file++) {
        const [pieceType, color] = this.getPiece(file, rank);
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

    return fen + " w KQkq - 0 2";
  }
}
