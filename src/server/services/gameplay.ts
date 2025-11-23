import { OnStart, Service } from "@flamework/core";
import { Object } from "@rbxts/luau-polyfill";
import { HttpService, Players } from "@rbxts/services";
import { Event, Function } from "shared/lifecycles";
import { Events, Functions } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, IsPromotion, Piece, Square } from "shared/board";
import { GetBestMove } from "shared/engine/bot";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard } from "shared/engine/fen";
import GetLegalMoves, { AnalyzeMates } from "shared/engine/legalMoves";
import { Datastore, DatastoredGame } from "./datastore";
import { computeNewRating, OpponentRating, PlayerRating } from "server/glicko2";
import { FullMove, PlayerSavedGame } from "shared/network";
import { act } from "@rbxts/react-roblox";

export type Game = {
  /* players */
  player1: number; // userid
  player2: number;

  player1draw: boolean;
  player2draw: boolean;

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
  moves: FullMove[];
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

  /* Utilities */
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
    if (!promotion) {
      BitBoard.movePiece(activeGame.board, from, to);
    } else {
      BitBoard.setPiece(activeGame.board, from, 0, 0);
      BitBoard.setPiece(activeGame.board, to, promotion, turn);
    }
    BitBoard.flipTurn(activeGame.board);

    /* PGN */
    activeGame.moves.push([from, to, promotion]);

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
      this.endGame(gameId);
    }

    /* Broadcast */
    Events.MoveMade.fire(this.Trackers[gameId], [from, to, promotion], turn);
    this.patchGame(gameId);

    if (activeGame.winner !== 0) delete this.Games[gameId];
  }
  private endGame(gameId: string) {
    const activeGame = this.Games[gameId];
    const [player1EloChange, player2EloChange] = this.adjustElo(
      activeGame.player1,
      activeGame.player2,
      activeGame.winner,
      gameId,
    );
    activeGame.player1eloDiff = player1EloChange;
    activeGame.player2eloDiff = player2EloChange;
    this.saveGame(gameId);
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
      oppUserId: number,
      opponents: OpponentRating[],
      score: number,
    ) => {
      const updatedOpponents = [
        ...opponents,
        {
          elo: opp.elo,
          rd: opp.rd,
          user: oppUserId,
          myRating: myRating.elo,
          moves: this.Games[gameId].moves.size(),
          date: os.time(),
          gameId,
          score,
        },
      ];

      const newRating = computeNewRating(myRating, updatedOpponents);
      newRating.elo = math.clamp(math.floor(newRating.elo), 100, 3500);
      const delta = newRating.elo - myRating.elo;
      return { newRating, delta, updatedOpponents };
    };

    // Player 1
    const r1 = compute(
      p1.rating,
      p2.rating,
      player2user?.UserId ?? -1,
      p1.opponents,
      score,
    );
    p1.rating = r1.newRating;
    p1.opponents = r1.updatedOpponents as typeof p1.opponents;
    this.db.players.get(player1user).write(p1);
    diff1 = r1.delta;

    // Player 2 (if human)
    if (player2user) {
      const r2 = compute(
        p2.rating,
        p1.rating,
        player1user.UserId,
        p2.opponents,
        1 - score,
      );
      p2.rating = r2.newRating;
      p2.opponents = r2.updatedOpponents as typeof p2.opponents;
      this.db.players.get(player1user).write(p2);
      diff2 = r2.delta;
    }

    return [diff1, diff2];
  }
  private async saveGame(gameId: string) {
    const activeGame = this.Games[gameId];
    const doc = await this.db.games.load(gameId);
    const save = {
      player1: activeGame.player1,
      player2: activeGame.player2,
      player1elo: activeGame.player1elo,
      player2elo: activeGame.player2elo,
      color: activeGame.color,
      winner: activeGame.winner,
      opening: activeGame.opening,
      moves: activeGame.moves,
    };
    print(gameId, save);
    doc.write(save);

    doc.close().catch(warn);
  }
  private patchGame(gameId: string, additional: Partial<Game> = {}) {
    const activeGame = this.Games[gameId];
    Events.PatchGame.fire(this.Trackers[gameId], {
      ...activeGame,
      ...additional,

      /* client does not need */
      lastMove: undefined,
      moves: undefined,
      board: undefined,
    });
  }
  private evaluate(gameId: string) {
    const activeGame = this.Games[gameId];
    if (!activeGame) return;

    const best = GetBestMove(activeGame.board, false);
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

      player1draw: false,
      player2draw: false,

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
      moves: [],
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

  /* Callbacks */
  @Event(Events.MakeMove)
  onMoveMade(
    player: Player,
    gameId: string,
    [from, to, promotion]: [Square, Square, Piece | undefined],
  ) {
    if (
      /* TODO: player2 can make a shit move on player1s behalf */
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
  @Event(Events.Resign)
  resign(player: Player, gameId: string) {
    const activeGame = this.Games[gameId];
    if (!activeGame) return;

    activeGame.analysis = "resign";
    activeGame.winner = player.UserId === activeGame.player1 ? 2 : 1;
    this.endGame(gameId);
    this.patchGame(gameId);

    delete this.Games[gameId];
  }
  @Event(Events.Draw)
  draw(player: Player, gameId: string, state: boolean) {
    const activeGame = this.Games[gameId];
    if (!activeGame) return false;

    if (state === false) {
      /* draw declined, remove both states */
      activeGame.player1draw = false;
      activeGame.player2draw = false;
    } else if (player.UserId === activeGame.player1) {
      activeGame.player1draw = true;
    } else if (player.UserId === activeGame.player2) {
      activeGame.player2draw = true;
    }

    if (activeGame.player1draw && activeGame.player2draw) {
      /* draw accepted! */
      print("drawn!");
      activeGame.analysis = "draw";
      activeGame.winner = 0;
      this.endGame(gameId);
      this.patchGame(gameId);

      delete this.Games[gameId];
    } else if (activeGame.player1draw !== activeGame.player2draw) {
      /* one player needs to be sent a draw request */
      const plr = Players.GetPlayerByUserId(
        activeGame.player1draw ? activeGame.player2 : activeGame.player1,
      );
      if (!plr) return;
      Events.DrawOffered.fire(plr);
    }
  }

  @Function(Functions.ListPlayerGames)
  requestPlayerGames(_: Player, target: Player): PlayerSavedGame[] {
    const playerData = this.db.players.get(target).read();
    const opponents = playerData.opponents;

    return opponents.map((x) => ({
      gameId: x.gameId,
      user: x.user,
      score: x.score,
      myRating: x.myRating,
      theirRating: x.elo,
      moves: x.moves,
      date: x.date,
    }));
  }
  @Function(Functions.RequestGame)
  async requestGame(_: Player, gameId: string): Promise<DatastoredGame> {
    const document = await this.db.games.load(gameId);
    const savedGame = document.read();
    print(gameId, savedGame);
    document.close();

    return savedGame;
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
