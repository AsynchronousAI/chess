import { Service } from "@flamework/core";
import { HttpService } from "@rbxts/services";
import { Event } from "server/lifecycles";
import { Events } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard, FEN } from "shared/engine/fen";
import GetLegalMoves from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";

export type Game = {
  /* players */
  player1: number;
  player2: number;

  player1time: number;
  player2time: number;

  lastMove: number;

  color: Color; // represents player1 color.

  /* board */
  board: BitBoard;
  pgn: PGN;
  opening: string;

  /* evaluation */
  eval: number;
  mate: number;
};

const BOT = true;

@Service()
export class Gameplay {
  private Games: Record<string, Game> = {};
  private Trackers: Record<string, Player[]> = {};
  private AwaitingGame: Array<Player> = [];

  private shrinkPatch(patch: Partial<Game>) {
    /* remove uneeded elements when sending a game patch to the client */
    return {
      ...patch,
      /* client does not need */
      lastMove: undefined,
      pgn: undefined,
      board: undefined,
    };
  }

  private move(gameId: string, from: Square, to: Square, promotion?: Piece) {
    const activeGame = this.Games[gameId];
    const legalMoves = GetLegalMoves(activeGame.board, from, true);
    const found = legalMoves.find((move) => move[0] === to);

    const currentTime = os.clock();

    /* illegal moves, in future check for promotions also */
    if (!found) {
      print("illegal move");
      return;
    }

    /* Special moves, castling & en passant */
    const closure = found[1];
    closure?.(activeGame.board);

    /* Deduct time */
    if (BitBoard.getTurn(activeGame.board) === activeGame.color) {
      activeGame.player1time -= currentTime - activeGame.lastMove;
    } else {
      activeGame.player2time -= currentTime - activeGame.lastMove;
    }
    activeGame.lastMove = os.clock();

    /* Broadcast */
    Events.MoveMade.fire(
      this.Trackers[gameId],
      [from, to, promotion],
      BitBoard.getTurn(activeGame.board),
    );
    this.evaluate(gameId, true);

    /* Board move */
    const captured = BitBoard.hasPiece(activeGame.board, to);
    if (!promotion) {
      BitBoard.movePiece(activeGame.board, from, to);
    } else {
      BitBoard.setPiece(activeGame.board, from, 0, 0);
      BitBoard.setPiece(
        activeGame.board,
        to,
        promotion,
        BitBoard.getTurn(activeGame.board),
      );
    }
    BitBoard.flipTurn(activeGame.board);

    /* PGN */
    print(FEN.toFEN(activeGame.board));
    PGN.move(activeGame.pgn, activeGame.board, from, to, promotion, captured);

    /* Opening */
    const opening = getOpening(activeGame.board);
    if (opening) {
      activeGame.opening = opening.name;
    }
  }
  private evaluate(gameId: string, rapid = false) {
    const activeGame = this.Games[gameId];

    /* Local (faster) */
    Events.Evaluate.fire(
      this.Trackers[gameId],
      this.shrinkPatch({
        opening: activeGame.opening,
      }),
    );

    if (rapid) return;

    /* HTTP Handled (slower) */
    const best = GetBestMoveAPI(activeGame.board);
    if (BOT && best.move) this.move(gameId, ...best.move);

    const stats = this.shrinkPatch({
      ...activeGame,
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
    });

    Events.Evaluate.fire(this.Trackers[gameId], stats);

    return stats;
  }
  private makeGame(player1: Player, player2?: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      /* Matchmaking */
      player1: player1.UserId,
      player2: player2 ? player2.UserId : -1,

      player1time: 300,
      player2time: 300,

      lastMove: os.clock(),

      color: 1,

      /* Board */
      board: BitBoard.branch(DefaultBoard),
      pgn: PGN.create(),
      opening: "Starting Position",

      /* Evaluation */
      eval: 0,
      mate: 0,
    };

    this.Trackers[id] = player2 ? [player1, player2] : [player1];
    this.Games[id] = activeGame;

    Events.AssignedGame.fire(this.Trackers[id], id, activeGame.color);
    this.evaluate(
      id,
      true,
    ); /* perform a quick initial evaluation to upsync clients */

    /* Bot starts as white */
    if (BOT && activeGame.color === 1) {
      this.evaluate(id);
    }
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
