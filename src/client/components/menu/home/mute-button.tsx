import React from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";

import { PrimaryButton } from "client/components/ui/primary-button";
import { Text } from "client/components/ui/text";
import { fonts } from "client/constants/fonts";
import { useRem } from "client/hooks";
import Atoms from "shared/atoms";
import { palette } from "shared/constants/palette";

export function MuteButton() {
	const rem = useRem();
	const musicMuted = useAtom(Atoms.IsMuted);

	return (
		<PrimaryButton
			onClick={() => Atoms.IsMuted(!musicMuted)}
			overlayGradient={new ColorSequence(musicMuted ? palette.text : palette.maroon)}
			size={new UDim2(0, rem(4), 0, rem(4))}
		>
			<Text
				font={fonts.inter.medium}
				text={!musicMuted ? "🔊" : "🔇"}
				textSize={rem(2)}
				size={new UDim2(1, 0, 1, 0)}
			/>
		</PrimaryButton>
	);
}
