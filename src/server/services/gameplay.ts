import { OnStart, Service } from "@flamework/core";
import { Object } from "@rbxts/luau-polyfill";
import { HttpService } from "@rbxts/services";
import { Event } from "server/lifecycles";
import { Events } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, Piece, Square } from "shared/board";
import { GetBestMoveAPI } from "shared/engine/api";
import { BitBoard } from "shared/engine/bitboard";
import { DefaultBoard, FEN } from "shared/engine/fen";
import GetLegalMoves, { AnalyzeMates } from "shared/engine/legalMoves";
import { PGN } from "shared/engine/pgn";

export type Game = {
  /* players */
  player1: number;
  player2: number;

  player1time: number;
  player2time: number;

  lastMove: number; // os.clock() of the last move

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

@Service()
export class Gameplay implements OnStart {
  private Games: Record<string, Game> = {};
  private Trackers: Record<string, Player[]> = {};
  private AwaitingGame: Array<Player> = [];

  private move(gameId: string, from: Square, to: Square, promotion?: Piece) {
    const activeGame = this.Games[gameId];
    const legalMoves = GetLegalMoves(activeGame.board, from, true);
    const found = legalMoves.find((move) => move[0] === to);
    const turn = BitBoard.getTurn(activeGame.board);

    const currentTime = os.clock();

    /* illegal moves, in future check for promotions also */
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
    print(FEN.toFEN(activeGame.board));
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

    /* Analysis */
    activeGame.analysis = AnalyzeMates(activeGame.board);
    if (activeGame.analysis === "stalemate") {
      activeGame.winner = 3;
    } else if (activeGame.analysis === "checkmate") {
      activeGame.winner = turn === activeGame.color ? 1 : 2;
    } else if (activeGame.analysis === "insufficent") {
      /* TODO: draw by timeout vs insufficient */
      activeGame.winner = 3;
    }

    /* Broadcast */
    Events.MoveMade.fire(this.Trackers[gameId], [from, to, promotion], turn);
    this.patchGame(gameId);
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
  private makeGame(player1: Player, player2?: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      /* Matchmaking */
      player1: player1.UserId,
      player2: player2 ? player2.UserId : -1,

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

    Events.AssignedGame.fire(this.Trackers[id], id, activeGame.color);
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
