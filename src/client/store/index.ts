import { combineProducers, InferState } from "@rbxts/reflex";

import { alertSlice } from "./alert";
import { menuSlice } from "./menu";

export type RootStore = typeof store;

export type RootState = InferState<RootStore>;

export function createStore() {
	const store = combineProducers({
		alert: alertSlice,
		menu: menuSlice,
	});

	return store;
}

export const store = createStore();
