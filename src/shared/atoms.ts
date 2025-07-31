import { atom } from "@rbxts/charm";
import { Board, Color, DefaultBoard, Square } from "./board";

/** UI Tab Types */
export type MenuPage = "home" | "skins" | "support";

/** Alert types */
export type AlertScope = "money" | "ranking";
export interface Alert {
	color: Color3;
	colorMessage?: Color3;
	colorSecondary?: Color3;
	duration: number;
	emoji: string;
	id: number;
	message: string;
	scope?: AlertScope;
	sound?: string;
	visible: boolean;
}

const Atoms = {
	/* Skin Picker */
	FocusedSkin: atom("__random__"),

	/* Menu (ported from littensy/slither) */
	Alerts: atom<Array<Alert>>([]),
	IsMenuOpen: atom(true),
	IsMuted: atom(false),
	CurrentPage: atom<MenuPage>("home"),

	/* Board */
	Board: atom<Board>(DefaultBoard),
	PlayingAs: atom<Color>("black"),
	HoldingPiece: atom<Square | undefined>(undefined),
	PossibleMoves: atom<Square[]>([]),
};

export default Atoms;
