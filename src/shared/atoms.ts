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
	Alerts: atom<Array<Alert>>([]),
	CurrentPage: atom<MenuPage>("home"),
	FocusedSkin: atom("__random__"),
	IsMenuOpen: atom(true),
	IsMuted: atom(false),
	Board: atom<Board>(DefaultBoard),
	PlayingAs: atom<Color>("black"),
	HoldingPiece: atom<Square | undefined>(undefined),
};

export default Atoms;
