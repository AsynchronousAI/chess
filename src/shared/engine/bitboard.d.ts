import { Color, Piece, Square } from "shared/board";

export type BitBoard = { side_to_move: Color };
export type BitBoardSave = {};
export type Move = {
  from: Square;
  to: Square;
  piece_type: Piece;
  captured: boolean;
  promotion: Piece;
  flags: {};
};

export namespace BitBoard {
  export function create(): BitBoard;

  export function to_buffer(board: BitBoard): buffer;
  export function from_buffer(buffer: buffer): BitBoard;

  export function from_fen(fen: string): BitBoard;
  export function to_fen(board: BitBoard): string;

  export function set_start_position(board: BitBoard): void;
  export function save_state(board: BitBoard): BitBoardSave;
  export function update_occupied(board: BitBoard): void;

  export function make_move(board: BitBoard, move: Move): void;
  export function unmake_move(
    board: BitBoard,
    move: Move,
    save: BitBoardSave,
  ): void;

  export function generate_legal_moves(
    board: BitBoard,
    filePseudoLegal?: boolean,
  ): Move[];
  export function generate_legal_moves_from(
    board: BitBoard,
    from: Square,
    filePseudoLegal?: boolean,
  ): Move[];
}
