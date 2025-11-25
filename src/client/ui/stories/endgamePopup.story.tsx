import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import PlayerList from "../playerList";
import { EndgamePopup } from "../endgamePopup";

const controls = {
  title: "You Win!",
  description: "by checkmate",
  rating: 1000,
  ratingChange: 5,
  open: true,
};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = <EndgamePopup {...props.controls} />;

    return component;
  },
};

export = story;
