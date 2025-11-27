import A from "./a.json";
import B from "./b.json";
import C from "./c.json";
import D from "./d.json";
import E from "./e.json";
import { BitBoard } from "shared/engine/bitboard";

const allOpenings: {
  [key: string]: {
    name: string;
    eco: string;
  };
} = { ...A, ...B, ...C, ...D, ...E };

export default function getOpening(board: BitBoard) {
  const lookingFor = BitBoard.to_fen(board).split(" ")[0];
  return allOpenings[lookingFor];
}
