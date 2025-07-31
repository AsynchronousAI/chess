import React from "@rbxts/react";

import { Vector, Flat, Wood } from "./images";
import { Image } from "client/components/ui/image";
import { Text } from "client/components/ui/text";
import { fonts } from "client/constants/fonts";
import { useMotion } from "client/hooks";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "shared/atoms";
import { useMemo } from "@rbxts/react";
import { IsSquareBlack, Square } from "shared/board";
import { palette } from "shared/constants/palette";

const DISPLAY_SQUARE_LABELS = false;
export function Piece(props: { letter: string; number: string; i: number; j: number }) {
	const [rotation, rotationMotion] = useMotion(0);

	/*** Get piece data */
	/** Get board data */
	const board = useAtom(Atoms.Board);
	const playingAs = useAtom(Atoms.PlayingAs);
	const iconPack = Wood;

	/* Load data */
	const location = useMemo(() => {
		return `${props.letter}${props.number}` as Square;
	}, [props.letter, props.number]);

	const colored = useMemo(() => {
		return IsSquareBlack(props.i, props.j);
	}, [props.i, props.j]);

	const pieceAtBoard = useMemo(() => {
		return board[location];
	}, [board, location]);

	const image = useMemo(() => {
		return pieceAtBoard ? iconPack[pieceAtBoard.color][pieceAtBoard.type] : undefined;
	}, [pieceAtBoard, iconPack]);

	/** Get some player/color based data */
	const boardJ = playingAs === "white" ? 7 - props.j : props.j;
	const isMyPiece = playingAs === pieceAtBoard?.color;

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
			key={location}
			Position={new UDim2(props.i * (1 / 8), 0, boardJ * (1 / 8), 0)}
			Size={new UDim2(1 / 8, 0, 1 / 8, 0)}
			BackgroundColor3={colored ? palette.base : palette.black}
			BorderSizePixel={0}
		>
			<textbutton
				Size={new UDim2(1, 0, 1, 0)}
				Text={""}
				BackgroundTransparency={1}
				Event={{ MouseEnter: onHover, MouseLeave: onLeave, MouseButton1Down: onDown, MouseButton1Up: onUp }}
			/>
			{DISPLAY_SQUARE_LABELS && (
				<Text
					textColor={palette.subtext0}
					textSize={24}
					font={fonts.inter.bold}
					text={location}
					size={new UDim2(1, 0, 1, 0)}
				/>
			)}
			{image ? <Image rotation={rotation} image={image} size={new UDim2(1, 0, 1, 0)} /> : <></>}
		</frame>
	);
}
