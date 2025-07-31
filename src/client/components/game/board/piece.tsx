import React, { useEffect, useRef, useState } from "@rbxts/react";

import { Image } from "client/components/ui/image";
import { Text } from "client/components/ui/text";
import { fonts } from "client/constants/fonts";
import { useMotion } from "client/hooks";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "shared/atoms";
import { useMemo } from "@rbxts/react";
import { Board, Color, IsSquareBlack, Square } from "shared/board";
import { palette } from "shared/constants/palette";
import { IconPack } from "./images";
import { useBindingListener } from "@rbxts/pretty-react-hooks";
import useMouse from "client/hooks/use-mouse";

const DISPLAY_SQUARE_LABELS = false;

export interface PieceProps {
	letter: string;
	number: string;
	i: number;
	j: number;
	board: Board;
	iconPack: IconPack;
	playingAs: Color;
	mousePos: Vector2;
}
export function Square(props: PieceProps) {
	/* Load data */
	const location = `${props.letter}${props.number}` as Square;
	const colored = IsSquareBlack(props.i, props.j);
	const boardJ = props.playingAs === "white" ? 7 - props.j : props.j;

	return (
		<frame
			key={location}
			Position={new UDim2(props.i * (1 / 8), 0, boardJ * (1 / 8), 0)}
			Size={new UDim2(1 / 8, 0, 1 / 8, 0)}
			BackgroundColor3={colored ? props.iconPack.filled : props.iconPack.unfilled}
			BorderSizePixel={0}
		>
			{DISPLAY_SQUARE_LABELS && (
				<Text
					textColor={palette.subtext0}
					textSize={24}
					font={fonts.inter.bold}
					text={location}
					size={new UDim2(1, 0, 1, 0)}
				/>
			)}
		</frame>
	);
}
export function Piece(props: PieceProps) {
	const holdingPiece = useAtom(Atoms.HoldingPiece);
	const containerRef = useRef<Frame>();

	const [rotation, rotationMotion] = useMotion(0);
	const [mouseRelativePosition, setMouseRelativePosition] = useState(new UDim2());

	useEffect(() => {
		const absolutePosition = containerRef.current?.AbsolutePosition;
		const absoluteSize = containerRef.current?.AbsoluteSize;
		if (!absolutePosition || !absoluteSize) return;
		setMouseRelativePosition(
			UDim2.fromOffset(
				props.mousePos.X - absolutePosition.X - absoluteSize.X / 2,
				props.mousePos.Y - absolutePosition.Y - absoluteSize.Y / 2,
			),
		);
	}, [props.mousePos]);

	/* Block data */
	const location = `${props.letter}${props.number}` as Square;
	const pieceAtBoard = props.board[location];
	const image = pieceAtBoard ? props.iconPack[pieceAtBoard.color][pieceAtBoard.type] : undefined;
	const isMyPiece = props.playingAs === pieceAtBoard?.color;
	const boardJ = props.playingAs === "white" ? 7 - props.j : props.j;

	/*** Events */
	const onHover = () => {
		if (!isMyPiece) return;
		rotationMotion.spring(7);
	};
	const onDown = () => {
		if (!isMyPiece) return;
		Atoms.HoldingPiece(location);
	};
	const onUp = () => {
		if (!isMyPiece) return;
		Atoms.HoldingPiece(undefined);
	};
	const onLeave = () => {
		rotationMotion.spring(0);
	};

	return (
		<frame
			ref={containerRef}
			key={location}
			Position={new UDim2(props.i * (1 / 8), 0, boardJ * (1 / 8), 0)}
			Size={new UDim2(1 / 8, 0, 1 / 8, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={2}
		>
			<textbutton
				Size={new UDim2(1, 0, 1, 0)}
				Text={""}
				BackgroundTransparency={1}
				Event={{ MouseEnter: onHover, MouseLeave: onLeave, MouseButton1Down: onDown, MouseButton1Up: onUp }}
			/>
			{image ? (
				<Image
					rotation={rotation}
					image={image}
					position={holdingPiece === location ? mouseRelativePosition : undefined}
					size={new UDim2(1, 0, 1, 0)}
					outlinePrecision={30}
					outlineThickness={6}
					outlineStartAngle={40}
					outlineColor={new Color3(0.35, 0.35, 0.35)}
				/>
			) : (
				<></>
			)}
		</frame>
	);
}
