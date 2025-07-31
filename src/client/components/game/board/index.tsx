import React, { useMemo, useState } from "@rbxts/react";
import { BOARD_LETTERS, BOARD_NUMBERS, IsSquareBlack, Square } from "shared/board";
import { palette } from "shared/constants/palette";
import { Piece } from "./piece";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "shared/atoms";
import { Vector, Flat, Wood } from "./images";
import useMouse from "client/hooks/use-mouse";

export default function Board() {
	const board = useAtom(Atoms.Board);
	const playingAs = useAtom(Atoms.PlayingAs);
	const mousePos = useMouse();
	const iconPack = Wood;

	return (
		<frame
			Size={new UDim2(1, 0, 1, 0)}
			BackgroundColor3={palette.base}
			Position={new UDim2(0.5, 0, 0.5, 0)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BorderSizePixel={0}
		>
			<uiaspectratioconstraint />

			{BOARD_LETTERS.map((letter, i) =>
				BOARD_NUMBERS.map((number, j) => (
					<Piece
						letter={letter}
						number={number}
						i={i}
						j={j}
						playingAs={playingAs}
						board={board}
						iconPack={iconPack}
						mousePos={mousePos}
					/>
				)),
			)}
		</frame>
	);
}
