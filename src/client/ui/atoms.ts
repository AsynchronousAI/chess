import { atom } from "@rbxts/charm";
import { Color, Square } from "shared/board";

import { Move } from "shared/engine/legalMoves";
import { EndgamePopupProps } from "./endgamePopup";
import { ConfirmationPopupProps } from "./confirmationPopup";

const Atoms = {
  Dragging: atom<boolean>(false),
  CurrentMove: atom<Square>(0),
  CheckedSquare: atom<Square>(-1),
  HoldingPiece: atom<Square | undefined>(undefined),
  PossibleMoves: atom<Move[]>([]),
  ViewingPlayer: atom<number>(0) /* userid */,
  EndgamePopup: atom<EndgamePopupProps>({
    title: "",
    rating: 0,
    ratingChange: 0,
    description: "",
    open: false,
    onNew: () => {},
    onRematch: () => {},
  }),
  ConfirmationPopup: atom<ConfirmationPopupProps>({
    title: "",
    description: "",
    open: false,
    onConfirm: () => {},
  }),
};

export default Atoms;
