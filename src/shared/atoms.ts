import { atom } from "@rbxts/charm";

export type MenuPage = "support" | "home" | "skins";
const Atoms = {
	IsMuted: atom(false),
	IsMenuOpen: atom(true),
	CurrentPage: atom<MenuPage>("home"),
	FocusedSkin: atom("__random__"),
};

export default Atoms;
