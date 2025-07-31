import { Board, Color, FILES, Piece, RANKS, Square } from "shared/board";

/* Direction Rules */
const SLIDE_DIRECTIONS: Partial<Record<Piece, [number, number][]>> = {
	rook: [
		[1, 0],
		[-1, 0],
		[0, 1],
		[0, -1],
	],
	bishop: [
		[1, 1],
		[1, -1],
		[-1, 1],
		[-1, -1],
	],
	queen: [
		[1, 0],
		[-1, 0],
		[0, 1],
		[0, -1],
		[1, 1],
		[1, -1],
		[-1, 1],
		[-1, -1],
	],
};
const FIXED_DIRECTIONS: Partial<Record<Piece, [number, number][]>> = {
	king: [
		[1, 0],
		[-1, 0],
		[0, 1],
		[0, -1],
		[1, 1],
		[1, -1],
		[-1, 1],
		[-1, -1],
	],
	knight: [
		[1, 2],
		[2, 1],
		[-1, 2],
		[-2, 1],
		[1, -2],
		[2, -1],
		[-1, -2],
		[-2, -1],
	],
};
const CUSTOM_DIRECTIONS: Partial<
	Record<Piece, (piece: { color: Color; type: Piece }, fy: number, fx: number, board: Board) => Square[]>
> = {
	pawn: (piece, fy, fx, board) => {
		const moves: Square[] = [];

		const dir = piece.color === "white" ? 1 : -1;
		const startRank = piece.color === "white" ? 1 : 6;

		// Forward move
		const oneStep = fy + dir;
		if (isOnBoard(FILES[fx], RANKS[oneStep]) && !board[coordsToSquare(fx, oneStep)]) {
			moves.push(coordsToSquare(fx, oneStep));

			// Two steps from start
			const twoStep = fy + dir * 2;
			if (fy === startRank && !board[coordsToSquare(fx, twoStep)]) {
				moves.push(coordsToSquare(fx, twoStep));
			}
		}

		// Captures
		for (const dx of [-1, 1]) {
			const nx = fx + dx;
			if (nx < 0 || nx > 7) continue;
			const captureSquare = coordsToSquare(nx, fy + dir);
			const target = board[captureSquare];
			if (target && target.color !== piece.color) {
				moves.push(captureSquare);
			}
		}

		return moves;
	},
};

/* Utility functions */
function isOnBoard(file: string, rank: string): boolean {
	return FILES.includes(file) && RANKS.includes(rank);
}
function squareToCoords(square: Square): [number, number] {
	const sChars = square.split("");
	const file = sChars[0];
	const rank = sChars[1];
	return [FILES.indexOf(file), RANKS.indexOf(rank)];
}
function coordsToSquare(file: number, rank: number) {
	return `${FILES[file]}${RANKS[rank]}` as Square;
}

export default function GetLegalMoves(board: Board, from: Square): Square[] {
	const piece = board[from];
	if (!piece) return [];

	const [fx, fy] = squareToCoords(from);
	let moves: Square[] = [];

	const addMove = (x: number, y: number) => {
		if (x < 0 || y < 0 || x >= 8 || y >= 8) return;
		const to = coordsToSquare(x, y);
		const target = board[to];
		if (!target || target.color !== piece.color) {
			moves.push(to);
		}
	};

	if (CUSTOM_DIRECTIONS[piece.type]) {
		const customMoves = CUSTOM_DIRECTIONS[piece.type]!(piece, fy, fx, board);
		moves = [...moves, ...customMoves];
	} else if (FIXED_DIRECTIONS[piece.type] !== undefined) {
		for (const [dx, dy] of FIXED_DIRECTIONS[piece.type]!) {
			addMove(fx + dx, fy + dy);
		}
	} else if (SLIDE_DIRECTIONS[piece.type] !== undefined) {
		for (const [dx, dy] of SLIDE_DIRECTIONS[piece.type]!) {
			let x = fx + dx;
			let y = fy + dy;
			while (x >= 0 && y >= 0 && x < 8 && y < 8) {
				const to = coordsToSquare(x, y);
				const target = board[to];
				if (!target) {
					moves.push(to);
				} else {
					if (target.color !== piece.color) {
						moves.push(to);
					}
					break;
				}
				x += dx;
				y += dy;
			}
		}
	}

	return moves;
}
