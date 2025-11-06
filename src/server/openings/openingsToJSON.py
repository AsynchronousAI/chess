import csv
import json
import os
import io
import chess.pgn

script_dir = os.path.dirname(os.path.abspath(__file__))
tsv_files = [f for f in os.listdir(script_dir) if f.endswith(".tsv")]

if not tsv_files:
    print("No TSV file found in the script directory.")
    exit(1)

for file in tsv_files:
    input_file = os.path.join(script_dir, file)
    output_file = os.path.splitext(input_file)[0] + ".json"

    # Read TSV
    with open(input_file, newline="", encoding="utf-8") as tsvfile:
        reader = csv.DictReader(tsvfile, delimiter="\t")
        data = {}
        for row in reader:
            pgn_text = row["pgn"]

            # Parse PGN and get final board FEN
            pgn_io = io.StringIO(pgn_text)
            game = chess.pgn.read_game(pgn_io)
            if game is None:
                print(f"Warning: Could not parse PGN: {pgn_text}")
                continue
            final_board = game.end().board()
            fen = final_board.fen().split(" ")[0]

            # Keep other fields as before
            data[fen] = {k: v for k, v in row.items()}

    # Write JSON
    with open(output_file, "w", encoding="utf-8") as jsonfile:
        json.dump(data, jsonfile, indent=2, ensure_ascii=False)

    print(f"Converted {input_file} → {output_file}")
