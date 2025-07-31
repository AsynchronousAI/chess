import { useViewport } from "@rbxts/pretty-react-hooks";
import React from "@rbxts/react";

import { Group } from "client/components/ui/group";
import { useOrientation, usePremium, useRem } from "client/hooks";
import { formatInteger } from "client/utils/format-integer";
import { DevelopmentProduct } from "shared/assets";
import { PREMIUM_BENEFIT } from "shared/constants/core";
import { palette } from "shared/constants/palette";

import { SupportHeart } from "./support-heart";
import { SupportProduct } from "./support-product";

export function SupportProducts() {
	const rem = useRem();
	const padding = rem(1.5);

	const viewport = useViewport();
	const orientation = useOrientation();
	const premium = usePremium();

	const getProductTitle = (money: number) => {
		if (premium) {
			money = math.floor(money * PREMIUM_BENEFIT);
		}

		return `$${formatInteger(money)}`;
	};

	const getProductDiscount = (money: number, discount?: string) => {
		return premium ? `<s>$${formatInteger(money)}</s> ${RobloxEmoji.Premium} BONUS!` : discount;
	};

	let index = 0;

	return (
		<scrollingframe
			CanvasSize={new UDim2(0, rem(70), 0, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Size={new UDim2(0, rem(70), 0, rem(36))}
			Position={new UDim2(0.5, 0, 0.5, 16)}
		>
			<uisizeconstraint MaxSize={viewport.map((v) => new Vector2(v.X, math.huge))} />

			{orientation === "portrait" && (
				<uipadding
					PaddingLeft={new UDim(0, padding)}
					PaddingRight={new UDim(0, padding)}
					PaddingTop={new UDim(0, -2 * padding)}
					PaddingBottom={new UDim(0, 2 * padding)}
				/>
			)}

			<Group size={new UDim2(0.6, -padding / 2, 1, 0)}>
				<SupportProduct
					index={index++}
					productId={DevelopmentProduct.MONEY_100}
					productTitle={getProductTitle(100)}
					productSubtitle="🍑  PEACH"
					productDiscount={getProductDiscount(100)}
					primaryColor={palette.yellow}
					secondaryColor={palette.peach}
					size={new UDim2(0.5, -padding / 2, 0.5, -padding / 2)}
					position={new UDim2(0, 0, 0, 0)}
				/>
				<SupportProduct
					index={index++}
					productId={DevelopmentProduct.MONEY_250}
					productTitle={getProductTitle(250)}
					productSubtitle="🍒  MAROON"
					productDiscount={getProductDiscount(250, "20% OFF")}
					primaryColor={palette.maroon}
					secondaryColor={palette.red}
					size={new UDim2(0.5, -padding / 2, 0.5, -padding / 2)}
					position={new UDim2(0, 0, 0.5, padding / 2)}
				/>
				<SupportProduct
					index={index++}
					productId={DevelopmentProduct.MONEY_500}
					productTitle={getProductTitle(500)}
					productSubtitle="🍐  GREEN"
					productDiscount={getProductDiscount(500, "20% OFF")}
					primaryColor={palette.teal}
					secondaryColor={palette.green}
					size={new UDim2(0.5, -padding / 2, 0.5, -padding / 2)}
					position={new UDim2(0.5, padding / 2, 0, 0)}
				/>
				<SupportProduct
					index={index++}
					productId={DevelopmentProduct.MONEY_1000}
					productTitle={getProductTitle(1000)}
					productSubtitle="💎  SAPPHIRE"
					productDiscount={getProductDiscount(1000, "20% OFF")}
					primaryColor={palette.sapphire}
					secondaryColor={palette.blue}
					size={new UDim2(0.5, -padding / 2, 0.5, -padding / 2)}
					position={new UDim2(0.5, padding / 2, 0.5, padding / 2)}
				/>
			</Group>

			<SupportProduct
				index={index++}
				productId={DevelopmentProduct.MONEY_5000}
				productTitle={getProductTitle(5000)}
				productSubtitle="💜  MAUVE"
				productDiscount={getProductDiscount(5000, "25% OFF")}
				primaryColor={palette.mauve}
				secondaryColor={palette.blue}
				size={new UDim2(0.4, -padding / 2, 1, 0)}
				position={new UDim2(0.6, padding / 2, 0, 0)}
			>
				<SupportHeart />
			</SupportProduct>
		</scrollingframe>
	);
}
