import { Networking } from "@flamework/networking";
import { Piece, Square } from "./board";
import { BitBoard } from "./engine/bitboard";

type FullMove = [
  Square,
  Square,
  Piece | undefined,
]; /* Piece|undefined is promotion. */
interface ClientToServerEvents {
  MakeMove(move: FullMove): void;
}
interface ServerToClientEvents {
  MoveMade(move: FullMove, evaluation: number, mate: number): void;
}

interface ClientToServerFunctions {}
interface ServerToClientFunctions {}

export const GlobalEvents = Networking.createEvent<
  ClientToServerEvents,
  ServerToClientEvents
>();
export const GlobalFunctions = Networking.createFunction<
  ClientToServerFunctions,
  ServerToClientFunctions
>();
