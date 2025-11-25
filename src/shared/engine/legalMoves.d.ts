//!native
//!optimize 2
import { Color, IsSquareBlack, Piece, Square } from "shared/board";
import { BitBoard } from "./bitboard";

export enum MoveType {
  Normal = 0,
  EnPassant = 1,
  CastleKingside = 2,
  CastleQueenside = 3,
  PawnDoubleMove = 4,
}

export type MoveExecutionResult = [
  Square /* start square */,
  Square? /* end square, undefined means piece removed */,
  string? /* identifier used for SFX */,
];

export type MoveExecutor = (
  branch: BitBoard,
  from: Square,
  to: Square,
  skip?: boolean, // this will not apply changes to the bitboard
) => MoveExecutionResult | void;

export type Move = [Square, MoveType];

export const MoveExecutors: Record<MoveType, MoveExecutor>;

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
): [Square, Square, undefined, MoveType][];
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
