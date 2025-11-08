import { Color } from "shared/board";

export const BOT = true;

export const generatePosition = (pos: [number, number], color: Color) =>
  new UDim2(pos[0] / 8, 0, (color === 1 ? pos[1] : 7 - pos[1]) / 8, 0);
