import { Networking } from "@flamework/networking";
import { Color, Piece, Square } from "./board";

type FullMove = [
  Square,
  Square,
  Piece | undefined,
]; /* Piece|undefined is promotion. */
interface ClientToServerEvents {
  MakeMove(move: FullMove): void;
  NewGame(): void;
}
interface ServerToClientEvents {
  Evaluate(
    gameStats: Partial<{
      move: FullMove;
      eval: number;
      mate: number;
      opening: string;
    }>,
  ): void;
  AssignedGame(color: Color): void;
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
