import { Board, Piece, Square } from "shared/board";

export function BoardToFen(board: Board) {
  const pieceMap: Record<Piece, string> = {
    pawn: "p",
    knight: "n",
    bishop: "b",
    rook: "r",
    queen: "q",
    king: "k",
  };

  const rows: string[] = [];

  // Go from rank 8 to rank 1
  for (let rank = 8; rank >= 1; rank--) {
    let row = "";
    let emptyCount = 0;

    for (const file of "abcdefgh") {
      const square = `${file}${rank}` as Square;
      const piece = board[square];

      if (!piece) {
        emptyCount++;
      } else {
        if (emptyCount > 0) {
          row += emptyCount;
          emptyCount = 0;
        }
        const symbol = pieceMap[piece.type];
        row += piece.color === "white" ? symbol.upper() : symbol;
      }
    }
    if (emptyCount > 0) row += emptyCount;
    rows.push(row);
  }

  // Return FEN string with dummy placeholders for turn/castling/etc.
  const position = rows.join("/");
  const turn = "w";
  const castling = "-";
  const enPassant = "-";
  const halfmove = "0";
  const fullmove = "1";

  return `${position} ${turn} ${castling} ${enPassant} ${halfmove} ${fullmove}`;
}
