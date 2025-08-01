import { OnStart, Service } from "@flamework/core";
import { HttpService } from "@rbxts/services";
import { Events, Functions } from "server/networking";
import { Board, Square } from "shared/board";
import { BoardToFen } from "shared/engine/formats";
import { Event } from "shared/lifecycles/event";

const API = "https://www.stockfish.online/api/s/v2.php?fen=%s&depth=%s";

@Service()
export class Stockfish implements OnStart {
	async stockfish(_player: Player, board: Board, depth: number = 2) {
		const url = API.format(BoardToFen(board), depth);
		const response = HttpService.GetAsync(url);
		const decoded = HttpService.JSONDecode(response) as Record<string, unknown>;

		const success = decoded.success as boolean;
		if (!success) return { success };

		const plan = (decoded.continuation as string).split(" "); /* d1e2 c7c5 ... */

		const startingSquare = plan[0].sub(0, 2) as Square;
		const endingSquare = plan[0].sub(3, 4) as Square;

		return {
			startingSquare,
			endingSquare,
			success,
		};
	}

	onStart(): void {
		Functions.BotMovement.setCallback((plr, board) => this.stockfish(plr, board));
	}
}
