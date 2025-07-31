import { lerpBinding } from "@rbxts/pretty-react-hooks";
import React, { useEffect, useMemo, useRef } from "@rbxts/react";
import { DelayRender } from "client/components/ui/delay-render";
import { springs } from "client/constants/springs";
import { useMotion, useRem } from "client/hooks";

import { Transition } from "../ui/transition";
import { useAtom } from "@rbxts/react-charm";
import Atoms, { MenuPage } from "shared/atoms";
import { effect, subscribe } from "@rbxts/charm";

interface MenuContainerProps extends React.PropsWithChildren {
	readonly page?: MenuPage;
}

const TRANSITION_DEFAULT = new UDim2(0, 0, 0, -2);
const TRANSITION_LEFT = new UDim2(0, -2, 0, 0);
const TRANSITION_RIGHT = new UDim2(0, 2, 0, 0);

const MENU_PAGES: readonly MenuPage[] = ["support", "home", "skins"] as const;
function getMenuDirection(from: MenuPage, to: MenuPage) {
	const fromIndex = MENU_PAGES.indexOf(from);
	const toIndex = MENU_PAGES.indexOf(to);

	if (fromIndex === -1 || toIndex === -1) {
		throw `Invalid menu page: ${from} -> ${to}`;
	}

	return fromIndex < toIndex ? "right" : "left";
}
export function MenuContainer({ page, children }: MenuContainerProps) {
	const rem = useRem();

	const isOpen = useAtom(Atoms.IsMenuOpen);
	const currentPage = useAtom(Atoms.CurrentPage);
	const visible = isOpen && (currentPage === page || page === undefined);

	const transitionFrom = useRef(rem(TRANSITION_DEFAULT));
	const [transition, transitionMotion] = useMotion(0);

	useEffect(() => {
		transitionMotion.spring(visible ? 1 : 0, springs.gentle);
	}, [visible]);

	// wrapped in useMemo instead of an effect so that it can update
	// the ref synchronously before its used in lerpBinding
	subscribe(Atoms.CurrentPage, (old, now) => {
		const direction = getMenuDirection(old, now);

		if (visible) {
			// ease in from menuTransition.direction
			transitionFrom.current = direction === "left" ? rem(TRANSITION_LEFT) : rem(TRANSITION_RIGHT);
		} else {
			// ease out to menuTransition.direction
			transitionFrom.current = direction === "left" ? rem(TRANSITION_RIGHT) : rem(TRANSITION_LEFT);
		}
	});

	useMemo(() => {
		if (!isOpen) {
			transitionFrom.current = rem(TRANSITION_DEFAULT);
		}
	}, [isOpen]);

	return (
		<DelayRender shouldRender={visible} unmountDelay={1}>
			<Transition
				groupTransparency={lerpBinding(transition, 1, 0)}
				size={new UDim2(1, 0, 1, 0)}
				position={lerpBinding(transition, transitionFrom.current, new UDim2())}
				clipsDescendants
			>
				{children}
			</Transition>
		</DelayRender>
	);
}
