import { Color, Piece as PieceType } from "shared/board";
import { IconPack } from "./images";

// Constants
export const BOT = true;

// Types
export interface PieceProps {
  pos: [number, number];
  location: number;
  iconPack: IconPack;
  playingAs: Color;
  piece: [PieceType, Color];
  locked: boolean;
}

export interface PromotionProps {
  location: number;
  color: Color;
  iconPack: IconPack;
  onPromote: (piece: PieceType | undefined) => void;
}

// Utilities
export const generatePosition = (pos: [number, number], color: Color) =>
  new UDim2(pos[0] / 8, 0, (color === 1 ? pos[1] : 7 - pos[1]) / 8, 0);
