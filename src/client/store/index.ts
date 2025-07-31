import { combineProducers, InferState } from "@rbxts/reflex";

export type RootStore = typeof store;

export type RootState = InferState<RootStore>;

export function createStore() {
	const store = combineProducers({
		//alert: alertSlice,
	});

	return store;
}

export const store = createStore();
