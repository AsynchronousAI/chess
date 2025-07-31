export class Chess {
	constructor();

	/**
	 * Returns whether the game is over (checkmate, stalemate, draw, etc.).
	 */
	isGameOver(): boolean;

	/**
	 * Returns an array of legal move strings in the current position.
	 */
	moves(): string[];

	/**
	 * Makes a move given in standard algebraic notation and updates the game state.
	 * @param move The move to make.
	 * @returns The move made or null if invalid.
	 */
	move(move: string): string | null;

	/**
	 * Returns the PGN (Portable Game Notation) of the current game.
	 */
	pgn(): string;
}
