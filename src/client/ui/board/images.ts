import { Color, Piece } from "shared/board";

export type IconPack = Record<Color, Partial<Record<Piece, string>>> &
  Record<"filled" | "unfilled" | "highlighted", Color3>;

export const Vector: IconPack = {
  [Color.black]: {
    [Piece.bishop]: "rbxassetid://136140010822585",
    [Piece.king]: "rbxassetid://73910995822505",
    [Piece.knight]: "rbxassetid://74175833765785",
    [Piece.pawn]: "rbxassetid://88189190189728",
    [Piece.queen]: "rbxassetid://131666092748180",
    [Piece.rook]: "rbxassetid://71469510707300",
  },
  [Color.white]: {
    [Piece.bishop]: "rbxassetid://111533007750457",
    [Piece.king]: "rbxassetid://99927036508926",
    [Piece.knight]: "rbxassetid://73555205966745",
    [Piece.pawn]: "rbxassetid://129904067140562",
    [Piece.queen]: "rbxassetid://131559723456580",
    [Piece.rook]: "rbxassetid://111571822588564",
  },
  filled: Color3.fromHex("#779569"),
  unfilled: Color3.fromHex("#EFEEE7"),
  highlighted: Color3.fromHex("BFDFF5"),
};
export const Wood: IconPack = {
  [Color.black]: {
    [Piece.bishop]: "rbxassetid://110213065954080",
    [Piece.king]: "rbxassetid://118018362244728",
    [Piece.knight]: "rbxassetid://88842092106176",
    [Piece.pawn]: "rbxassetid://122373638635418",
    [Piece.queen]: "rbxassetid://121803237289345",
    [Piece.rook]: "rbxassetid://127454143660696",
  },
  [Color.white]: {
    [Piece.bishop]: "rbxassetid://101129009933460",
    [Piece.king]: "rbxassetid://72252737188864",
    [Piece.knight]: "rbxassetid://75387791138794",
    [Piece.pawn]: "rbxassetid://78892092935303",
    [Piece.queen]: "rbxassetid://85854632266679",
    [Piece.rook]: "rbxassetid://77981604292493",
  },
  filled: Color3.fromHex("#B58863"),
  unfilled: Color3.fromHex("#F0D9B5"),
  highlighted: Color3.fromHex("#F3CE8D"),
};
