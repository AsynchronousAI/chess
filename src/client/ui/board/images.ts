import { Color, Piece } from "shared/board";

export type IconPack = Record<Color, Record<Piece, string>> &
  Record<"filled" | "unfilled", Color3>;

export const Vector: IconPack = {
  black: {
    bishop: "rbxassetid://136140010822585",
    king: "rbxassetid://73910995822505",
    knight: "rbxassetid://74175833765785",
    pawn: "rbxassetid://88189190189728",
    queen: "rbxassetid://131666092748180",
    rook: "rbxassetid://71469510707300",
  },
  white: {
    bishop: "rbxassetid://111533007750457",
    king: "rbxassetid://99927036508926",
    knight: "rbxassetid://73555205966745",
    pawn: "rbxassetid://129904067140562",
    queen: "rbxassetid://131559723456580",
    rook: "rbxassetid://111571822588564",
  },
  filled: new Color3(1, 1, 1),
  unfilled: new Color3(0, 0, 0),
};
export const Wood: IconPack = {
  black: {
    bishop: "rbxassetid://110213065954080",
    king: "rbxassetid://118018362244728",
    knight: "rbxassetid://88842092106176",
    pawn: "rbxassetid://122373638635418",
    queen: "rbxassetid://121803237289345",
    rook: "rbxassetid://127454143660696",
  },
  white: {
    bishop: "rbxassetid://101129009933460",
    king: "rbxassetid://72252737188864",
    knight: "rbxassetid://75387791138794",
    pawn: "rbxassetid://78892092935303",
    queen: "rbxassetid://85854632266679",
    rook: "rbxassetid://77981604292493",
  },
  filled: Color3.fromHex("#B58863"),
  unfilled: Color3.fromHex("#F0D9B5"),
};
export const Flat: IconPack = {
  black: {
    bishop: "rbxassetid://92142353835929",
    king: "rbxassetid://117143786828665",
    knight: "rbxassetid://78725689313044",
    pawn: "rbxassetid://137391088362886",
    queen: "rbxassetid://140170890678854",
    rook: "rbxassetid://87166956390690",
  },
  white: {
    bishop: "rbxassetid://120207586996136",
    king: "rbxassetid://85626256806842",
    knight: "rbxassetid://76033760634711",
    pawn: "rbxassetid://91468336670577",
    queen: "rbxassetid://133499444299396",
    rook: "rbxassetid://131053145085973",
  },
  filled: new Color3(0.5, 0.5, 0.5),
  unfilled: new Color3(0, 0, 0),
};
