import { Color, Piece, Square } from "shared/board";

export type BitBoard = {
  side_to_move: Color;
  pieces: Record<Color, Record<Piece, vector>>;
  occupied: Record<Color | "all", vector>;
  castling_rights: {
    white_king_side: boolean;
    white_queen_side: boolean;
    black_king_side: boolean;
    black_queen_side: boolean;
  };
  en_passant_square?: Square;
  halfmove_clock: number;
  fullmove_number: number;
};
export type Move = number;

export namespace BitBoard {
  export function create(blank?: boolean): BitBoard;
  export function clone(board: BitBoard): BitBoard;

  export function hash(board: BitBoard): string;

  export function to_buffer(board: BitBoard): buffer;
  export function from_buffer(buffer: buffer): BitBoard;

  export function from_fen(fen: string): BitBoard;
  export function to_fen(board: BitBoard): string;

  export function set_start_position(board: BitBoard): void;
  export function update_occupied(board: BitBoard): void;

  export function make_move(board: BitBoard, move: Move): void;

  export function generate_legal_moves(
    board: BitBoard,
    filePseudoLegal?: boolean,
    color?: Color,
  ): Move[];
  export function generate_legal_moves_from(
    board: BitBoard,
    from: Square,
    filePseudoLegal?: boolean,
    color?: Color,
  ): Move[];
  export function is_square_attacked(
    board: BitBoard,
    square: Square,
    by_color: Color,
  ): boolean;

  export function get_piece(
    board: BitBoard,
    square: Square,
  ): [Piece, Color] | undefined;
  export function find_piece(
    board: BitBoard,
    piece_type: Piece,
    color: Color,
  ): Square;

  export function get_all_pieces(
    board: BitBoard,
  ): Array<[Piece, Color, Square]>;

  export function get_game_state(
    board: BitBoard,
  ):
    | "checkmate"
    | "stalemate"
    | "insufficent"
    | "timeout"
    | "resign"
    | "draw"
    | "";

  export function separate_square_index(loc: number): [number, number];
  export function get_square_index(file: number, rank: number): number;
}
