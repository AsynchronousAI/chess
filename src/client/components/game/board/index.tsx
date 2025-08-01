import React, { useMemo, useState } from "@rbxts/react";
import { BOARD_LETTERS, BOARD_NUMBERS } from "shared/board";
import { palette } from "shared/constants/palette";
import { Piece, Square } from "./piece";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "shared/atoms";
import { Vector, Flat, Wood } from "./images";

export default function Board() {
	const board = useAtom(Atoms.Board);
	const playingAs = useAtom(Atoms.PlayingAs);
	const menuOpen = useAtom(Atoms.IsMenuOpen);
	const iconPack = Wood;

	return (
		<frame
			Size={new UDim2(1, 0, 1, 0)}
			BackgroundColor3={palette.base}
			Position={new UDim2(0.5, 0, 0.5, 0)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BorderSizePixel={0}
			Visible={!menuOpen}
		>
			<textbutton
				Size={new UDim2(1, 0, 1, 0)}
				BackgroundTransparency={1}
				Event={{
					MouseButton1Up: () => Atoms.HoldingPiece(undefined),
				}}
			/>
			<uiaspectratioconstraint />

			{BOARD_LETTERS.map((letter, i) =>
				BOARD_NUMBERS.map((number, j) => (
					<>
						<Square
							letter={letter}
							number={number}
							i={i}
							j={j}
							playingAs={playingAs}
							board={board}
							iconPack={iconPack}
						/>
						<Piece
							letter={letter}
							number={number}
							i={i}
							j={j}
							playingAs={playingAs}
							board={board}
							iconPack={iconPack}
						/>
					</>
				)),
			)}
		</frame>
	);
}
