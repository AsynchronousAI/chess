import type { Storybook } from "@rbxts/ui-labs";

const storybook: Storybook = {
	groupRoots: false,
	name: "Components",
	storyRoots: [script.Parent!],
};

export = storybook;
