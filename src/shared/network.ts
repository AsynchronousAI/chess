import { Networking } from "@flamework/networking";
import { Piece, Square } from "./board";
import { BitBoard } from "./engine/bitboard";

interface ClientToServerEvents {}
interface ServerToClientEvents {
  MoveMade(
    move: [Square, Square, Piece | undefined],
    evaluation: number,
    mate: number,
  ): void;
}

interface ClientToServerFunctions {
  MakeMove(
    move: [
      Square,
      Square,
      Piece | undefined /* the last Piece|undefined is for promotion! */,
    ],
  ): BitBoard;
}
interface ServerToClientFunctions {}

export const GlobalEvents = Networking.createEvent<
  ClientToServerEvents,
  ServerToClientEvents
>();
export const GlobalFunctions = Networking.createFunction<
  ClientToServerFunctions,
  ServerToClientFunctions
>();
