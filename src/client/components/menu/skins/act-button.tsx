import { composeBindings, lerpBinding } from "@rbxts/pretty-react-hooks";
import React, { useEffect, useMemo } from "@rbxts/react";
import { PrimaryButton } from "client/components/ui/primary-button";
import { Shadow } from "client/components/ui/shadow";
import { Text } from "client/components/ui/text";
import { fonts } from "client/constants/fonts";
import { springs } from "client/constants/springs";
import { useMotion, useRem } from "client/hooks";
import { palette } from "shared/constants/palette";

export function ActButton() {
	const [textWidth, textWidthMotion] = useMotion(0);
	const [gradientSpin, gradientSpinMotion] = useMotion(0);
	const [hover, hoverMotion] = useMotion(0);

	const [primary, primaryMotion] = useMotion(new Color3());
	const [secondary, secondaryMotion] = useMotion(new Color3());
	const rem = useRem();

	const { size, gradient } = useMemo(() => {
		const size = textWidth.map((width) => {
			return new UDim2(0, width + rem(3), 0, rem(4.5));
		});

		const gradient = composeBindings(primary, secondary, (primary, secondary) => {
			return new ColorSequence(primary, secondary);
		});

		return { size, gradient };
	}, [rem]);

	useEffect(() => {
		primaryMotion.spring(palette.red);
		secondaryMotion.spring(palette.peach);
	});

	return (
		<PrimaryButton
			onClick={() => {
				gradientSpinMotion.spring(gradientSpin.getValue() + 180, springs.molasses);
			}}
			onHover={(hovered) => hoverMotion.spring(hovered ? 1 : 0)}
			overlayGradient={gradient}
			overlayRotation={gradientSpin}
			anchorPoint={new Vector2(0.5, 1)}
			size={size}
			position={new UDim2(0.5, 0, 1, -rem(19))}
		>
			<Shadow
				shadowColor={palette.white}
				shadowTransparency={lerpBinding(hover, 0.5, 0.2)}
				shadowSize={rem(1)}
				shadowPosition={rem(-0.25)}
				zIndex={0}
			>
				<uigradient Color={gradient} Rotation={gradientSpin} />
			</Shadow>

			<Text
				change={{
					TextBounds: (rbx) => {
						textWidthMotion.spring(rbx.TextBounds.X);
					},
				}}
				richText
				font={fonts.inter.medium}
				text={"🎨  Equip"}
				textColor={palette.base}
				textSize={rem(1.5)}
				size={new UDim2(1, 0, 1, 0)}
				clipsDescendants
			/>
		</PrimaryButton>
	);
}
