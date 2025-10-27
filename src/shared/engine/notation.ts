import { FILES, Square } from "shared/board";

export namespace Notation {
  export function parseSquare(square: string): Square {
    const [file, rank] = square.split("");
    return [FILES.indexOf(file as (typeof FILES)[number]), tonumber(rank)! - 1];
  }
  export function encodeSquare(square: Square): string {
    const [file, rank] = square;
    return FILES[file] + tostring(rank + 1);
  }
  export function parseLan(lan: string): [Square, Square] {
    const [from, to] = [lan.sub(0, 2), lan.sub(3, 4)];
    return [parseSquare(from), parseSquare(to)];
  }
}
