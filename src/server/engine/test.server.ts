import { Chess } from "./chess";

const chess = new Chess();

while (!chess.isGameOver()) {
	const moves = chess.moves();
	const move = moves[math.floor(math.random() * moves.size())];
	chess.move(move);
}
print(chess.pgn());
