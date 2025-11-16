import { Controller, OnStart } from "@flamework/core";
import React from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";
import { createPortal, createRoot } from "@rbxts/react-roblox";
import { Players } from "@rbxts/services";
import Atoms from "client/ui/atoms";
import Board from "client/ui/board";
import { EndgamePopup } from "client/ui/endgamePopup";
import PlayerList from "client/ui/playerList";

function GameRoot() {
  const popup = useAtom(Atoms.Popup);
  const viewingPlayer = useAtom(Atoms.ViewingPlayer);

  return (
    <screengui ZIndexBehavior="Sibling" IgnoreGuiInset>
      <Board />
      {viewingPlayer > 0 && <PlayerList player={Players.LocalPlayer.UserId} />}
      <EndgamePopup {...popup} />
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
