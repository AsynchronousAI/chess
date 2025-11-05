import { Service } from "@flamework/core";
import { HttpService } from "@rbxts/services";
import { Event, Function } from "server/lifecycles";
import { Events, Functions } from "server/network";
import { Color, DefaultFEN, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { FEN } from "shared/engine/fen";

@Service()
export class Gameplay {
  private target?: Player;
  private color: Color = Color.white;
  private board = FEN.fromFEN(BitBoard.create(), DefaultFEN);

  move(from: Square, to: Square, promotion?: Piece) {
    if (!promotion) {
      BitBoard.movePiece(this.board, from, to);
    } else {
      BitBoard.setPiece(this.board, from, 0, 0);
      BitBoard.setPiece(this.board, to, promotion, this.color);
    }
  }
  evaluate() {
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
    this.target = player;
    this.move(from, to, promotion);
    BitBoard.flipTurn(this.board);

    this.evaluate();
  }
}
