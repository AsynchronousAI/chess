import { Controller, OnStart } from "@flamework/core";
import React from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";
import { createPortal, createRoot } from "@rbxts/react-roblox";
import { Players } from "@rbxts/services";
import Atoms from "client/ui/atoms";
import Board from "client/ui/board";
// import { ConfirmationPopup } from "client/ui/confirmationPopup";
// import { EndgamePopup } from "client/ui/endgamePopup";
// import { Menu } from "client/ui/menu";
// import PlayerList from "client/ui/playerList";

function GameRoot() {
  // const endgamePopup = useAtom(Atoms.EndgamePopup);
  // const confirmationPopup = useAtom(Atoms.ConfirmationPopup);
  // const viewingPlayer = useAtom(Atoms.ViewingPlayer);

  return (
    <screengui ZIndexBehavior="Sibling" IgnoreGuiInset>
      <Board />
      {/*{viewingPlayer > 0 && <PlayerList player={Players.LocalPlayer.UserId} />}*/}
      {/*<ConfirmationPopup {...confirmationPopup} />
      <EndgamePopup {...endgamePopup} />
      <Menu />*/}
    </screengui>
  );
}

@Controller({})
export class GuiController implements OnStart {
  private playerGui = Players.LocalPlayer.WaitForChild("PlayerGui");

  onStart() {
    const root = createRoot(new Instance("Folder"));
    root.render(createPortal(<GameRoot />, this.playerGui));
  }
}
