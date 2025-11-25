import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { ConfirmationPopup } from "../confirmationPopup";

const controls = {
  title: "Draw",
  description: "opponent offered draw",
  open: true,
};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = <ConfirmationPopup {...props.controls} />;

    return component;
  },
};

export = story;
