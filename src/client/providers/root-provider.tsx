import React from "@rbxts/react";
import { ReflexProvider } from "@rbxts/react-reflex";

import { RemProvider, RemProviderProps } from "./rem-provider";

export function RootProvider({ baseRem, remOverride, children }: RemProviderProps) {
	return (
		<RemProvider baseRem={baseRem} remOverride={remOverride}>
			{children}
		</RemProvider>
	);
}
