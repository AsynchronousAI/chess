import { atom } from "@rbxts/charm";

export type MenuPage = "support" | "home" | "skins";

export type AlertScope = "ranking" | "money";
export interface Alert {
	id: number;
	scope?: AlertScope;
	emoji: string;
	message: string;
	color: Color3;
	colorSecondary?: Color3;
	colorMessage?: Color3;
	duration: number;
	visible: boolean;
	sound?: string;
}

const Atoms = {
	IsMuted: atom(false),
	IsMenuOpen: atom(true),
	CurrentPage: atom<MenuPage>("home"),
	FocusedSkin: atom("__random__"),
	Alerts: atom<Alert[]>([]),
};

export default Atoms;
