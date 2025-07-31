import { lerpBinding } from "@rbxts/pretty-react-hooks";
import React, { useEffect } from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";
import { useSelector } from "@rbxts/react-reflex";
import { Image } from "client/components/ui/image";
import { springs } from "client/constants/springs";
import { useMotion } from "client/hooks";
import { images } from "shared/assets";
import Atoms from "shared/atoms";
import { palette } from "shared/constants/palette";

export function MenuVignette() {
	const open = useAtom(Atoms.IsMenuOpen);
	const [transition, transitionMotion] = useMotion(0);

	useEffect(() => {
		if (open) {
			transitionMotion.spring(1, springs.molasses);
		} else {
			transitionMotion.spring(0, springs.molasses);
		}
	}, [open]);

	return (
		<Image
			image={images.ui.vignette}
			imageColor={palette.crust}
			imageTransparency={lerpBinding(transition, 1, 0)}
			backgroundColor={palette.crust}
			backgroundTransparency={lerpBinding(transition, 1, 0.8)}
			scaleType="Crop"
			size={new UDim2(1, 0, 1, 0)}
		/>
	);
}
