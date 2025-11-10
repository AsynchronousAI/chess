import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { EndgamePopup, EndgamePopupProps } from "../endgamePopup";

const controls = {
  title: "You Won!",
  description: "Black wins by checkmate",
};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = (
      <EndgamePopup {...(props.controls as EndgamePopupProps)} />
    );

    return component;
  },
};

export = story;
