import { OnStart, Service } from "@flamework/core";
import { Object } from "@rbxts/luau-polyfill";
import { HttpService, Players } from "@rbxts/services";
import { Event } from "shared/lifecycles";
import { Events } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, IsPromotion, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard, FEN } from "shared/engine/fen";
import GetLegalMoves, { AnalyzeMates } from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";
import { Datastore } from "./datastore";
import { computeNewRating, OpponentRating, PlayerRating } from "server/glicko2";

export type Game = {
  /* players */
  player1: number; // userid
  player2: number;

  /* Elo */
  player1elo: number;
  player2elo: number;

  player1eloDiff: number;
  player2eloDiff: number;

  /* Timer */
  player1time: number;
  player2time: number;

  lastMove: number; // os.clock() of the last move

  /* Roles */
  winner: number; // either 1 or 2 for player, 0 for none, 3 for draw.
  color: Color; // represents player1 color.

  /* board */
  board: BitBoard;
  pgn: PGN;
  opening: string;

  /* evaluation */
  analysis: ReturnType<typeof AnalyzeMates>;
  eval: number;
  mate: number;
};

const BOT = true;
const BOT_ELO = 3500;

@Service()
export class Gameplay implements OnStart {
  private Games: Record<string, Game> = {};
  private Trackers: Record<string, Player[]> = {};
  private AwaitingGame: Array<Player> = [];

  constructor(private readonly db: Datastore) {}

  private async move(
    gameId: string,
    from: Square,
    to: Square,
    promotion?: Piece,
  ) {
    const activeGame = this.Games[gameId];
    const legalMoves = GetLegalMoves(activeGame.board, from, true);
    const found = legalMoves.find((move) => move[0] === to);
    const turn = BitBoard.getTurn(activeGame.board);

    const currentTime = os.clock();

    /* illegal moves, in future check for promotions also */
    if (
      promotion !== undefined &&
      !IsPromotion(to, ...BitBoard.getPiece(activeGame.board, from))
    ) {
      print("illegal promotion");
      return;
    }
    if (!found) {
      print("illegal move");
      return;
    }

    /* Special moves, castling & en passant */
    const closure = found[1];
    closure?.(activeGame.board);

    /* Board move */
    const captured = BitBoard.hasPiece(activeGame.board, to);
    if (!promotion) {
      BitBoard.movePiece(activeGame.board, from, to);
    } else {
      BitBoard.setPiece(activeGame.board, from, 0, 0);
      BitBoard.setPiece(activeGame.board, to, promotion, turn);
    }
    BitBoard.flipTurn(activeGame.board);

    /* PGN */
    PGN.move(activeGame.pgn, activeGame.board, from, to, promotion, captured);

    /* Recompute Opening */
    const opening = getOpening(activeGame.board);
    if (opening) {
      activeGame.opening = opening.name;
    }

    /* Deduct time */
    if (turn === activeGame.color) {
      activeGame.player1time -= currentTime - activeGame.lastMove;
    } else {
      activeGame.player2time -= currentTime - activeGame.lastMove;
    }
    activeGame.lastMove = os.clock();

    /* Is this an endgame? */
    activeGame.analysis = AnalyzeMates(activeGame.board);
    if (activeGame.analysis === "stalemate") {
      activeGame.winner = 3;
    } else if (activeGame.analysis === "checkmate") {
      activeGame.winner = turn === activeGame.color ? 1 : 2;
    } else if (activeGame.analysis === "insufficent") {
      /* TODO: draw by timeout vs insufficient */
      activeGame.winner = 3;
    }

    /* If so, then compute elo change */
    if (activeGame.winner !== 0) {
      const [player1EloChange, player2EloChange] = this.adjustElo(
        activeGame.player1,
        activeGame.player2,
        activeGame.winner,
        gameId,
      );
      activeGame.player1eloDiff = player1EloChange;
      activeGame.player2eloDiff = player2EloChange;
    }

    /* Broadcast */
    Events.MoveMade.fire(this.Trackers[gameId], [from, to, promotion], turn);
    this.patchGame(gameId);
  }

  private adjustElo(
    player1: number,
    player2: number,
    endGame: number,
    gameId: string,
  ): [number, number] {
    const player1user = Players.GetPlayerByUserId(player1);
    const player2user = player2
      ? Players.GetPlayerByUserId(player2)
      : undefined;
    if (!player1user) return [0, 0];

    const defaultBot = {
      rating: { elo: BOT_ELO, rd: 30, vol: 0.01 },
      opponents: [],
    };

    const score = endGame === 1 ? 1 : endGame === 2 ? 0 : 0.5;

    let diff1 = 0;
    let diff2 = 0;

    const p1 = { ...this.db.players.get(player1user).read() };
    const p2 = player2user
      ? { ...this.db.players.get(player2user).read() }
      : defaultBot;

    const compute = (
      myRating: PlayerRating,
      opp: PlayerRating,
      opponents: OpponentRating[],
      score: number,
    ) => {
      const updatedOpponents = [
        ...opponents,
        {
          elo: opp.elo,
          rd: opp.rd,
          gameId,
          score,
        },
      ];

      const newRating = computeNewRating(myRating, updatedOpponents);
      newRating.elo = math.clamp(math.floor(newRating.elo), 100, 3500);
      const delta = newRating.elo - myRating.elo;
      return { newRating, delta };
    };

    // Player 1
    const r1 = compute(p1.rating, p2.rating, p1.opponents, score);
    p1.rating = r1.newRating;
    this.db.players.get(player1user).write(p1);
    diff1 = r1.delta;

    // Player 2 (if human)
    if (player2user) {
      const r2 = compute(p2.rating, p1.rating, p2.opponents, 1 - score);
      p2.rating = r2.newRating;
      this.db.players.get(player1user).write(p2);
      diff2 = r2.delta;
    }

    return [diff1, diff2];
  }

  private patchGame(gameId: string, additional: Partial<Game> = {}) {
    const activeGame = this.Games[gameId];
    Events.PatchGame.fire(this.Trackers[gameId], {
      ...activeGame,
      ...additional,

      /* client does not need */
      lastMove: undefined,
      pgn: undefined,
      board: undefined,
    });
  }
  private evaluate(gameId: string) {
    const activeGame = this.Games[gameId];

    const best = GetBestMoveAPI(activeGame.board);
    if (BOT && best.move) this.move(gameId, ...best.move);

    this.patchGame(gameId, {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
    });
  }
  private async makeGame(player1: Player, player2?: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      /* Matchmaking */
      player1: player1.UserId,
      player2: player2 ? player2.UserId : -1,

      player1elo: this.db.players.get(player1).read().rating.elo,
      player2elo: player2
        ? this.db.players.get(player2).read().rating.elo
        : BOT_ELO,

      player1eloDiff: 0,
      player2eloDiff: 0,

      player1time: 300,
      player2time: 300,

      lastMove: os.clock(),

      winner: 0,
      color: 0,

      /* Board */
      board: BitBoard.branch(DefaultBoard),
      pgn: PGN.create(),
      opening: "Starting Position",

      /* Evaluation */
      analysis: "",
      eval: 0,
      mate: 0,
    };

    this.Trackers[id] = player2 ? [player1, player2] : [player1];
    this.Games[id] = activeGame;

    Events.AssignedGame.fire(this.Trackers[id], id);
    this.patchGame(
      id,
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

  /* Timeout checks */
  onStart() {
    while (task.wait(1)) {
      for (const [id, currentGame] of Object.entries(this.Games)) {
        if (currentGame.analysis !== "") return; /* game ended */

        const currentTurn = BitBoard.getTurn(currentGame.board);

        let timedOut = 0; /* 1 means player 1, 2 means player 2, 0 means no timeouts */
        if (currentTurn === currentGame.color) {
          /* Check for player 1 timeout */
          if (os.clock() - currentGame.lastMove > currentGame.player1time)
            timedOut = 1;
        } else {
          /* Check for player 2 timeout */
          if (os.clock() - currentGame.lastMove > currentGame.player2time)
            timedOut = 2;
        }

        if (timedOut > 0) {
          currentGame.analysis = "timeout";
          currentGame.winner = timedOut === 1 ? 2 : 1;
          if (timedOut === 1) currentGame.player1time = 0;
          else currentGame.player2time = 0;

          this.patchGame(id);
        }
      }
    }
  }
}
