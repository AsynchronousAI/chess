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

  move(from: Square, to: Square, promotion?: Piece) {
    if (!promotion) {
      BitBoard.movePiece(this.board, from, to);
    } else {
      BitBoard.setPiece(this.board, from, 0, 0);
      BitBoard.setPiece(this.board, to, promotion, this.color);
    }
    this.PGN.move(this.board, to, promotion);
    print(getOpening(this.board));
  }
  bot() {
    const best = GetBestMoveAPI(this.board);
    this.move(...best.move!);
    BitBoard.flipTurn(this.board);
    if (this.target) {
      task.wait(0.25); /* bot is too fast! */
      Events.MoveMade.fire(
        this.target,
        best.move!,
        best.eval,
        tonumber(best.mate) ?? 0,
      );
    }
  }

  @Event(Events.MakeMove)
  onMoveMade(
    player: Player,
    [from, to, promotion]: [Square, Square, Piece | undefined],
  ) {
    if (this.target !== player) return;
    this.move(from, to, promotion);
    BitBoard.flipTurn(this.board);

    this.bot();
  }
  @Event(Events.NewGame)
  newGame(player: Player) {
    this.target = player;
    this.color = 0; //math.random(0, 1) as Color;
    print(this.color);

    Events.AssignedGame.fire(player, this.color);
    if ((this.color as Color) === 1) {
      this.bot();
    }
  }
}
