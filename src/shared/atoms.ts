import { atom } from "@rbxts/charm";

export type MenuPage = "home" | "skins" | "support";

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
};

export default Atoms;
