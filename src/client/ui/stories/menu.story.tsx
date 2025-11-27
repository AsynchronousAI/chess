import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { Menu } from "../menu";

const controls = {};

const story = {
  react: React,
  reactRoblox: ReactRoblox,
  controls: controls,
  story: (props: { controls: typeof controls }) => {
    const component = <Menu />;

    return component;
  },
};

export = story;
