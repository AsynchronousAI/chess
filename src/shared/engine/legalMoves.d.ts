//!native
//!optimize 2
import { Color, IsSquareBlack, Piece, Square } from "shared/board";
import { BitBoard } from "./bitboard";

export type Move =
  | [Square]
  | [
      Square,
      (
        branch: BitBoard,
        skip?: boolean, // this will not apply changes to the bitboard
      ) =>
        | [
            Square /* start square */,
            Square? /* end square, undefined means piece removed */,
            string? /* identifier used for SFX */,
          ]
        | void,
    ];

/* Export */
export function IsSquareAttacked(
  board: BitBoard,
  target: Square,
  attacker: Color,
): Piece;
export default function GetLegalMoves(
  board: BitBoard,
  from: Square,
  checks?: boolean,
  turn?: Color,
): Move[];
export function GetAllLegalMoves(
  board: BitBoard,
  turn: Color,
  checks?: boolean,
  cache?: boolean,
): [Square, Square][];
export function AnalyzeMates(
  board: BitBoard,
):
  | "checkmate"
  | "stalemate"
  | "insufficent"
  | "timeout"
  | "resign"
  | "draw"
  | "";
