import { Controller, OnStart } from "@flamework/core";
import React from "@rbxts/react";
import { createPortal, createRoot } from "@rbxts/react-roblox";
import { Players } from "@rbxts/services";

@Controller({})
export class GuiController implements OnStart {
  private playerGui = Players.LocalPlayer.WaitForChild("PlayerGui");

  onStart() {
    const root = createRoot(new Instance("Folder"));
    root.render(createPortal(<screengui></screengui>, this.playerGui));
  }
}
