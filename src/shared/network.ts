import { Networking } from "@flamework/networking";
import { Color, Piece, Square } from "./board";
import { Game } from "server/services/gameplay";
import { Datastore, DatastoredGame } from "server/services/datastore";

export type FullMove = [
  Square,
  Square,
  Piece | undefined,
]; /* Piece|undefined is promotion. */
export interface PlayerSavedGame {
  /* unlike a normal game this just stores information that will be shown to the user */
  gameId: string;
  user: number;
  score: 0 | 0.5 | 1;
  myRating: number;
  theirRating: number;
  moves: number;
  date: number;
}

interface ClientToServerEvents {
  MakeMove(gameId: string, move: FullMove): void;
  NewGame(): void;
}
interface ServerToClientEvents {
  PatchGame(gameStats: Partial<Game>): void;
  MoveMade(move: FullMove, turn: Color): void;
  AssignedGame(gameId: string): void;
}

interface ClientToServerFunctions {
  ListPlayerGames(player: Player): PlayerSavedGame[];
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
