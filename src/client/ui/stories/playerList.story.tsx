import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import PlayerList from "../playerList";

const controls = {};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = <PlayerList player={3287336566} />;

    return component;
  },
};

export = story;
