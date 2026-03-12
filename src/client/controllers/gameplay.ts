import { Controller, OnStart } from "@flamework/core";
import { useInterval } from "@rbxts/pretty-react-hooks";
import { RefObject, useState } from "@rbxts/react";
import { Players, SoundService } from "@rbxts/services";
import { Events, Functions } from "client/network";
import Atoms from "client/ui/atoms";
import { ChessBoardRef } from "client/ui/board/Board";
import { SoundEffects } from "client/ui/board/sfx";
import { Event } from "shared/lifecycles";
import { Game } from "server/services/gameplay";
import { Color, Piece, Square } from "shared/board";
import { BitBoard, Move as MoveType } from "shared/engine/bitboard";
import { EvaluationBarRef } from "client/ui/board/EvaluationBar";
import { FullMove } from "shared/network";
import { Move } from "shared/engine/move";

@Controller()
export class Gameplay {
  private takenPieces: [Piece[], Piece[]][] = [[[], []]];
  /* [
    0: [ [pawn, knight], [rook] ] // move 1, player 1 has a pawn + knight, while player 2 has a rook
    ]
  */

  private board = BitBoard.create();
  private moveHistory: Array<{
    move: MoveType;
    additionallyMoved?: [Square, Square?];
    sfx: keyof typeof SoundEffects;
    state: BitBoard;
  }> = [];
  private activeGame: Partial<Game> = {};
  private gameId = "";
  private playingAs = Color.white;
  public locked = false;

  private chessBoard?: React.RefObject<ChessBoardRef>;
  private evalBar?: React.RefObject<EvaluationBarRef>;

  /* Methods */
  private findMoveData(from: Square, to: Square, board: BitBoard = this.board) {
    const allMoves = BitBoard.generate_legal_moves_from(board, from, false);
    const move = allMoves.find((v) => Move.getTo(v) === to);
    if (!move) return undefined;
    return move;
  }
  private handleCapture(
    to: Square,
    color: Color,
    board: BitBoard = this.board,
  ) {
    const capturedVal = board.pieceTable[to];
    const captured =
      capturedVal !== undefined
        ? ([bit32.rshift(capturedVal, 6), bit32.band(capturedVal, 63)] as const)
        : undefined;

    if (board === this.board) {
      const prev: [Piece[], Piece[]] =
        this.takenPieces.size() > 0
          ? [
              [...this.takenPieces[this.takenPieces.size() - 1][0]],
              [...this.takenPieces[this.takenPieces.size() - 1][1]],
            ]
          : [[], []];
      this.takenPieces.push(prev);
    }

    if (captured !== undefined) {
      const piece = captured[0];
      const idx = color === this.activeGame.color ? 0 : 1;
      if (board === this.board)
        this.takenPieces[this.takenPieces.size() - 1][idx].push(piece);
    }
    return captured ? true : false;
  }
  private animateBoard(moved: [Square, Square?, Piece?][]) {
    if (Atoms.Dragging()) {
      this.chessBoard?.current?.setBoard(this.board);
    } else {
      this.chessBoard?.current?.animateBoard(moved);
    }
  }
  private pushMove(
    move: MoveType,
    additionallyMoved: [Square, Square?] | undefined,
    sfx: keyof typeof SoundEffects,
    myMove: boolean,
  ) {
    this.moveHistory.push({
      move,
      sfx,
      additionallyMoved,
      state: BitBoard.clone(this.board),
    });
    Atoms.CurrentMove(this.moveHistory.size() - 1);

    const from = Move.getFrom(move);
    const to = Move.getTo(move);
    const promotion = Move.getPromotion(move);

    if (myMove) {
      Atoms.PossibleMoves([]);
      Events.MakeMove(this.gameId, [from, to, promotion]);
    } else if (Atoms.HoldingPiece()) {
      Atoms.PossibleMoves(
        BitBoard.generate_legal_moves_from(
          this.board,
          Atoms.HoldingPiece()!,
          false,
          this.playingAs,
        ),
      );
    }
  }
  private getAnalysisDescription(
    analysis: ReturnType<typeof BitBoard.get_game_state>,
  ) {
    if (analysis === "checkmate") return "by checkmate";
    else if (analysis === "stalemate") return "by stalemate";
    else if (analysis === "insufficent") return "by insufficient material";
    else if (analysis === "timeout") return "on time";
    else if (analysis === "resign") return "by resignation";
    else if (analysis === "draw") return "draw by agreement";

    return "";
  }
  private clearGame() {
    this.chessBoard?.current?.setBoard(BitBoard.create());
    this.evalBar?.current?.setEval(0);
    this.evalBar?.current?.setMate(0);

    this.board = BitBoard.create();
    this.activeGame = {};
    this.gameId = "";
    this.takenPieces = [];
    this.moveHistory.clear();

    Atoms.CheckedSquare(-1);
  }
  private playSFX(sfx: keyof typeof SoundEffects) {
    const newAudio = new Instance("Sound", SoundService);
    newAudio.SoundId = SoundEffects[sfx];
    newAudio.Play();
    newAudio.Ended.Connect(() => newAudio.Destroy());
  }

  /* Exported Methods */
  public newGame(bot: boolean) {
    this.clearGame();

    Events.NewGame(bot);
  }
  public async loadGame(gameId: string) {
    this.clearGame();
    this.locked = true;
    this.gameId = gameId;

    const partial = await Functions.RequestGame(gameId);
    this.activeGame = partial;

    for (const [index, move] of pairs(partial.moves)) {
      this.movePiece(move, false, index % 2);
    }
  }
  public movePiece(
    move: FullMove,
    myMove: boolean = false,
    color: Color = myMove ? this.playingAs : 1 - this.playingAs,
    overrideBoard: BitBoard | undefined = undefined, //  used when we are just visually moving
    alsoMove?: [Square, Square?],
  ) {
    const [from, to, promotion] = move;

    let moveData = this.findMoveData(from, to, overrideBoard);
    if (!moveData) return;

    const captured = this.handleCapture(to, color, overrideBoard);
    let moved: [Square, Square?, Piece?][] = [move];

    if (alsoMove) moved.push(alsoMove);
    if (!overrideBoard) {
      if (promotion) moveData = Move.setPromotion(moveData, promotion);
      const a = BitBoard.make_move(this.board, moveData);
      const record = BitBoard.get_undo_record_data(
        a[0],
        a[1],
        a[2],
        a[3],
        a[4],
      );
      if (record.additionallyMoved)
        moved.push(record.additionallyMoved as [Square, Square?, Piece?]);
    }
    this.animateBoard(moved);

    const opponentsKing = BitBoard.find_piece(
      overrideBoard ?? this.board,
      Piece.king,
      1 - color,
    );
    if (opponentsKing === undefined || opponentsKing < 0) {
      error("No king!");
    }

    const check = BitBoard.is_square_attacked(
      overrideBoard ?? this.board,
      opponentsKing,
      color,
    );
    Atoms.CheckedSquare(check ? opponentsKing : -1);

    /* SFX */
    let sfx: keyof typeof SoundEffects = "Move";

    if (check) {
      sfx = "Check";
    } else if (Move.getCastling(moveData)[0]) {
      sfx = "Castle";
    } else if (captured) {
      sfx = "Capture";
    }

    this.playSFX(sfx);

    if (!overrideBoard)
      this.pushMove(moveData, moved[1] as [Square, Square?], sfx, myMove);
  }

  /* Events */
  @Event(Events.AssignedGame)
  assignedGame(gameId: string) {
    this.gameId = gameId;
    this.activeGame.opening = "Starting Position";
    this.chessBoard?.current?.setBoard(this.board);
    this.moveHistory.clear();
  }
  @Event(Events.PatchGame)
  patchGame(newGame: Partial<Game>) {
    if (newGame.eval) this.evalBar?.current?.setEval(newGame.eval);
    if (newGame.mate) this.evalBar?.current?.setMate(newGame.mate);

    this.activeGame = { ...this.activeGame, ...newGame };

    /* Analysis, endgame popup */
    if (newGame.analysis && newGame.winner) {
      let title;
      if (newGame.winner === 3) title = "Draw";
      else if (newGame.winner === 1 && newGame.color === this.playingAs)
        title = "You Win!";
      else title = "You Lose!";
    }

    /* Assign this.playingAs */
    if (newGame.color !== undefined) {
      this.playingAs = newGame.color;
    }
  }
  @Event(Events.MoveMade)
  onMoveMade(move: FullMove, turn: Color) {
    if (turn === this.playingAs) return; /* i am already this color */
    this.movePiece(move, false);
  }

  /* Ref setters */
  public setChessBoard(chessBoard: RefObject<ChessBoardRef>) {
    this.chessBoard = chessBoard;
  }
  public setEvaluationBar(evalBar: RefObject<EvaluationBarRef>) {
    this.evalBar = evalBar;
  }

  /* Hooks */
  public useTakenPieces() {
    const [takenPieces, setTakenPieces] = useState<typeof this.takenPieces>([]);
    useInterval(() => {
      if (takenPieces !== this.takenPieces) {
        setTakenPieces(this.takenPieces);
      }
    }, 0.1);
    return takenPieces;
  }
  public useBoard(): BitBoard {
    const [board, setBoard] = useState<BitBoard>(this.board);
    useInterval(() => {
      if (BitBoard.hash(board) !== BitBoard.hash(this.board))
        setBoard(BitBoard.clone(this.board));
    }, 0.1);
    return board;
  }
  public useMoveHistory(): typeof this.moveHistory {
    const [mH, setMH] = useState(this.moveHistory);
    useInterval(() => {
      if (mH !== this.moveHistory) {
        setMH(this.moveHistory);
      }
    }, 0.1);
    return mH;
  }
  public usePlayingAs(): Color {
    const [playingAsState, setPlayingAs] = useState<Color>(this.playingAs);
    useInterval(() => {
      if (playingAsState !== this.playingAs) {
        setPlayingAs(this.playingAs);
      }
    }, 0.1);
    return playingAsState;
  }
  public useActiveGame(): Partial<Game> {
    const [activeGameState, setActiveGame] = useState<Partial<Game>>(
      this.activeGame,
    );
    useInterval(() => {
      setActiveGame({ ...this.activeGame });
    }, 0.1);
    return activeGameState;
  }
}
