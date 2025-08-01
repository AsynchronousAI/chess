import { Networking } from "@flamework/networking";
import { Board, Square } from "./board";

interface ClientToServerEvents {}

interface ServerToClientEvents {}

interface ClientToServerFunctions {
	BotMovement(board: Board): { startingSquare?: Square; endingSquare?: Square; success: boolean };
}

interface ServerToClientFunctions {}

export const GlobalEvents = Networking.createEvent<ClientToServerEvents, ServerToClientEvents>();
export const GlobalFunctions = Networking.createFunction<ClientToServerFunctions, ServerToClientFunctions>();
