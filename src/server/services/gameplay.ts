import { Service } from "@flamework/core";
import { HttpService } from "@rbxts/services";
import { Event } from "shared/lifecycles";
import { Events } from "server/network";
import getOpening from "server/openings/getOpening";
import { Color, IsPromotion, Piece, Square } from "shared/board";
import { BitBoard } from "shared/engine/bitboard";
import { GetBestMove } from "server/bot";
import { Move } from "shared/engine/move";

export type Game = {
  playerId: number;

  winner: number; // 1 for player, 2 for bot, 0 for none, 3 for draw.
  color: Color; // represents player color.

  board: BitBoard;
  moves: Array<[Square, Square, Piece | undefined]>;
  opening: string;

  analysis: ReturnType<typeof BitBoard.get_game_state>;
  eval: number;
  mate: number;
};

@Service()
export class Gameplay {
  private Games: Record<string, Game> = {};
  private Trackers: Record<string, Player[]> = {};

  constructor() {}

  /* Utilities */
  private async move(
    gameId: string,
    from: Square,
    to: Square,
    promotion?: Piece,
  ) {
    const activeGame = this.Games[gameId];
    const turn = activeGame.board.side_to_move!;

    /* illegal moves, in future check for promotions also */
    const fromPieceVal = activeGame.board.pieceTable[from];
    const fromPiece =
      fromPieceVal !== undefined
        ? ([
            bit32.rshift(fromPieceVal, 6),
            bit32.band(fromPieceVal, 63),
          ] as const)
        : undefined;
    if (
      fromPiece === undefined ||
      (promotion !== undefined && !IsPromotion(to, fromPiece[0], fromPiece[1]))
    ) {
      return;
    }

    const allMoves = BitBoard.generate_legal_moves_from(
      activeGame.board,
      from,
      false,
    );
    const move = allMoves.find((m) => Move.getTo(m) === to);
    if (!move) {
      return;
    }

    BitBoard.make_move(activeGame.board, move);

    activeGame.moves.push([from, to, promotion]);

    /* Recompute Opening */
    const opening = getOpening(activeGame.board);
    if (opening) {
      activeGame.opening = opening.name;
    }

    /* Is this an endgame? */
    activeGame.analysis = BitBoard.get_game_state(activeGame.board);
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

    if (activeGame.winner !== 0) delete this.Games[gameId];
  }
  private patchGame(gameId: string, additional: Partial<Game> = {}) {
    const activeGame = this.Games[gameId];
    if (!activeGame) return;
    Events.PatchGame.fire(this.Trackers[gameId], {
      ...activeGame,
      ...additional,

      /* client does not need */
      moves: undefined,
      board: undefined,
    });
  }
  private evaluate(gameId: string) {
    const activeGame = this.Games[gameId];
    if (!activeGame) return;

    const best = GetBestMove(activeGame.board);
    if (best.move) {
      this.move(
        gameId,
        Move.getFrom(best.move),
        Move.getTo(best.move),
        Move.getPromotion(best.move),
      );
    }

    this.patchGame(gameId, {
      eval: best.eval,
      mate: tonumber(best.mate) ?? 0,
    });
  }
  private async makeGame(player: Player) {
    const id = HttpService.GenerateGUID();
    const activeGame: Game = {
      playerId: player.UserId,

      winner: 0,
      color: 0,

      /* Board */
      board: BitBoard.create(),
      moves: [],
      opening: "Starting Position",

      /* Evaluation */
      analysis: "",
      eval: 0,
      mate: 0,
    };

    this.Trackers[id] = [player];
    this.Games[id] = activeGame;

    Events.AssignedGame.fire(this.Trackers[id], id);
    this.patchGame(id);

    /* Bot starts as white */
    if (activeGame.color === 1) {
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
    if (this.Games[gameId]?.playerId !== player.UserId) return;

    this.move(gameId, from, to, promotion);
    this.evaluate(gameId);
  }
  @Event(Events.NewGame)
  newGame(player: Player, _bot: boolean) {
    this.makeGame(player);
  }
}
