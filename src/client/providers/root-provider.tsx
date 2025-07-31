import React from "@rbxts/react";

import type { RemProviderProps } from "./rem-provider";
import { RemProvider } from "./rem-provider";

export function RootProvider({ baseRem, children, remOverride }: RemProviderProps) {
	return (
		<RemProvider baseRem={baseRem} remOverride={remOverride}>
			{children}
		</RemProvider>
	);
}
