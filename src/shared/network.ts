import { Networking } from "@flamework/networking";
import { Color, Piece, Square } from "./board";
import { Game } from "server/services/gameplay";

export type FullMove = [
  Square,
  Square,
  Piece | undefined,
]; /* Piece|undefined is promotion. */
interface ClientToServerEvents {
  MakeMove(gameId: string, move: FullMove): void;
  NewGame(): void;
}
interface ServerToClientEvents {
  PatchGame(gameStats: Partial<Game>): void;
  MoveMade(move: FullMove, turn: Color): void;
  AssignedGame(gameId: string): void;
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
