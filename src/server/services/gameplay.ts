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
  /* players */
  player1: number;
  player2: number;

  color: Color; // represents player1 color.

  /* board */
  board: BitBoard;
  pgn: PGN;
  opening: string;

  /* evaluation */
  eval: number;
  mate: number;
};

const BOT = false;

@Service()
export class Gameplay {
  private Games: Record<string, Game> = {};
  private Trackers: Record<string, Player[]> = {};
  private AwaitingGame: Array<Player> = [];

  private move(gameId: string, from: Square, to: Square, promotion?: Piece) {
    const activeGame = this.Games[gameId];

    /* Broadcast */
    Events.MoveMade.fire(
      this.Trackers[gameId],
      [from, to, promotion],
      BitBoard.getTurn(activeGame.board),
    );

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
    Events.Evaluate.fire(this.Trackers[gameId], {
      opening: activeGame.opening,
    });

    /* HTTP Handled (slower) */
    const best = GetBestMoveAPI(activeGame.board);
    if (BOT) this.move(gameId, ...best.move);

    const stats = {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
      opening: activeGame.opening,
    };

    Events.Evaluate.fire(this.Trackers[gameId], {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
      opening: activeGame.opening,
    });

    return stats;
  }

  @Event(Events.MakeMove)
  onMoveMade(
    player: Player,
    gameId: string,
    [from, to, promotion]: [Square, Square, Piece | undefined],
  ) {
    if (
      this.Games[gameId]?.player1 !== player.UserId &&
      this.Games[gameId]?.player2 !== player.UserId
    )
      return; /* no jurisdiction */

    this.move(gameId, from, to, promotion);
    this.evaluate(gameId);
  }

  makeGame(player1: Player, player2?: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      /* Matchmaking */
      player1: player1.UserId,
      player2: player2 ? player2.UserId : -1,
      color: 0,

      /* Board */
      board: FEN.fromFEN(DefaultFEN),
      pgn: PGN.create(),
      opening: "Starting Position",

      /* Evaluation */
      eval: 0,
      mate: 0,
    };

    this.Trackers[id] = player2 ? [player1, player2] : [player1];
    this.Games[id] = activeGame;

    Events.AssignedGame.fire(player1, id, activeGame.color);
    if (player2) Events.AssignedGame.fire(player2, id, 1 - activeGame.color);

    /* Bot starts as white */
    if (BOT && activeGame.color === 1) {
      this.evaluate(id);
    }
  }

  @Event(Events.NewGame)
  newGame(player: Player) {
    const nextPlayer = this.AwaitingGame.pop();

    if (BOT) {
      this.makeGame(player);
    } else if (nextPlayer) {
      this.makeGame(player, nextPlayer);
    } else {
      this.AwaitingGame.push(player);
    }
  }
}
