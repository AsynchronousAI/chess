import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import Board from "../board";

const controls = {};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = <Board />;

    return component;
  },
};

export = story;
