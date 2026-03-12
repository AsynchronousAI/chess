import { Networking } from "@flamework/networking";
import { Color, Piece, Square } from "./board";
import { Game } from "server/services/gameplay";
import { Datastore, DatastoredGame } from "server/services/datastore";

export type FullMove = [Square, Square, Piece | undefined];

interface ClientToServerEvents {
  MakeMove(gameId: string, move: FullMove): void;
  NewGame(bot: boolean): void;
}
interface ServerToClientEvents {
  PatchGame(gameStats: Partial<Game>): void;
  MoveMade(move: FullMove, turn: Color): void;
  AssignedGame(gameId: string): void;
}

interface ClientToServerFunctions {
  RequestGame(gameId: string): DatastoredGame;
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
