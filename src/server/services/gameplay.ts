import { Service } from "@flamework/core";
import { HttpService } from "@rbxts/services";
import { Event } from "server/lifecycles";
import { Events } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, DefaultFEN, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { FEN } from "shared/engine/fen";
import { PGN } from "shared/engine/pgn";

export type Game = {
  host: Player;
  color: Color;
  board: BitBoard;
  pgn: PGN;
  opening: string;

  /* evaluation */
  eval: number;
  mate: number;
};

@Service()
export class Gameplay {
  private Games: Record<string, Game> = {};

  private move(gameId: string, from: Square, to: Square, promotion?: Piece) {
    const activeGame = this.Games[gameId];

    /* Board move */
    if (!promotion) {
      BitBoard.movePiece(activeGame.board, from, to);
    } else {
      BitBoard.setPiece(activeGame.board, from, 0, 0);
      BitBoard.setPiece(activeGame.board, to, promotion, activeGame.color);
    }
    BitBoard.flipTurn(activeGame.board);

    /* Attributes, PGN & opening */
    PGN.move(activeGame.pgn, activeGame.board, to, promotion);

    const opening = getOpening(activeGame.board);
    if (opening) {
      activeGame.opening = opening.name;
    }
  }
  evaluate(gameId: string) {
    const activeGame = this.Games[gameId];

    /* Local (faster) */
    Events.Evaluate.fire(activeGame.host, {
      opening: activeGame.opening,
    });

    /* HTTP Handled (slower) */
    const best = GetBestMoveAPI(activeGame.board);
    this.move(gameId, ...best.move);

    const stats = {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
      opening: activeGame.opening,
    };

    Events.Evaluate.fire(activeGame.host, {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
      opening: activeGame.opening,
    });
    Events.MoveMade.fire(activeGame.host, best.move);

    return stats;
  }

  @Event(Events.MakeMove)
  onMoveMade(
    player: Player,
    gameId: string,
    [from, to, promotion]: [Square, Square, Piece | undefined],
  ) {
    if (this.Games[gameId]?.host !== player) return; /* no jurisdiction */

    this.move(gameId, from, to, promotion);
    this.evaluate(gameId);
  }
  @Event(Events.NewGame)
  newGame(player: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      /* Matchmaking */
      host: player,
      color: 0,

      /* Board */
      board: FEN.fromFEN(DefaultFEN),
      pgn: PGN.create(),
      opening: "Starting Position",

      /* Evaluation */
      eval: 0,
      mate: 0,
    };

    this.Games[id] = activeGame;

    Events.AssignedGame.fire(player, id, activeGame.color);
    if (activeGame.color === 1) {
      this.evaluate(id);
    }
  }
}
