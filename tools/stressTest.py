import os
import random
import subprocess

import chess
import chess.engine


def random_fen():
    """Generate a random legal position by making random moves from starting position."""
    board = chess.Board()
    moves_to_make = random.randint(5, 35)  # random number of half-moves
    for _ in range(moves_to_make):
        if board.is_game_over():
            break
        move = random.choice(list(board.legal_moves))
        board.push(move)
    return board.fen(), board


def count_legal_moves_python(board):
    return board.legal_moves.count()


def count_legal_moves_cli(fen):
    """Uses Stockfish CLI to get perft 1 move count"""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    luau_file = os.path.join(base_dir, "tests", "search.test.luau")
    cmd = ["luau", luau_file, "-a", fen]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return int(result.stdout.strip())


def main():
    for i in range(1, 1000):
        fen, board = random_fen()
        python_count = count_legal_moves_python(board)

        try:
            cli_count = count_legal_moves_cli(fen)
        except Exception as e:
            print("error running CLI engine:", e)
            cli_count = None

        print(f"{fen}")
        if python_count != cli_count:
            print(f"counts differ! {python_count} != {cli_count}")
            break


if __name__ == "__main__":
    main()
