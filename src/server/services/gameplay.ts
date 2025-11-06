import { Service } from "@flamework/core";
import { Event, Function } from "server/lifecycles";
import { Events, Functions } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, DefaultFEN, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { FEN } from "shared/engine/fen";
import { PGN } from "shared/engine/pgn";

@Service()
export class Gameplay {
  private target?: Player;
  private color: Color = Color.black;

  private board = FEN.fromFEN(DefaultFEN);
  private PGN = new PGN();
  private opening = "Starting Position";

  move(from: Square, to: Square, promotion?: Piece) {
    if (!promotion) {
      BitBoard.movePiece(this.board, from, to);
    } else {
      BitBoard.setPiece(this.board, from, 0, 0);
      BitBoard.setPiece(this.board, to, promotion, this.color);
    }
    BitBoard.flipTurn(this.board);
    this.PGN.move(this.board, to, promotion);

    const opening = getOpening(this.board);
    if (opening) {
      this.opening = opening.name;
    }
  }
  evaluate() {
    /* Local (faster) */
    if (this.target)
      Events.Evaluate.fire(this.target, {
        opening: this.opening,
      });

    /* HTTP Handled (slower) */
    const best = GetBestMoveAPI(this.board);
    this.move(...best.move);

    const stats = {
      move: best.move,
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
      opening: this.opening,
    };

    if (this.target) Events.Evaluate.fire(this.target, stats);

    return stats;
  }

  @Event(Events.MakeMove)
  onMoveMade(
    player: Player,
    [from, to, promotion]: [Square, Square, Piece | undefined],
  ) {
    if (this.target !== player) return;
    this.move(from, to, promotion);
    this.evaluate();
  }
  @Event(Events.NewGame)
  newGame(player: Player) {
    this.target = player;
    this.color = 0; //math.random(0, 1) as Color;
    print(this.color);

    Events.AssignedGame.fire(player, this.color);
    if ((this.color as Color) === 1) {
      this.evaluate();
    }
  }
}
