import React, { Binding, useEffect } from "@rbxts/react";
import { Color, Piece as PieceType } from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import Atoms from "../atoms";
import { Frame } from "@rbxts/better-react-components";
import { default as GetLegalMoves } from "shared/engine/legalMoves";
import { Image } from "../image";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "../usePx";
import { PieceProps, generatePosition } from "./shared";

export function Piece(props: PieceProps) {
  const board = useAtom(Atoms.Board);
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const px = usePx();

  const [offsetY, offsetYMotion] = useMotion(0);

  const [pos, posMotion] = useMotion(
    generatePosition(props.pos, props.playingAs),
  );
  useEffect(
    () =>
      posMotion.tween(generatePosition(props.pos, props.playingAs), {
        style: Enum.EasingStyle.Quint,
        time: 0.2,
      }),

    [props.pos],
  );

  /* Block data */
  const image = props.piece
    ? props.iconPack[props.piece[1]][props.piece[0]]
    : undefined;
  const isMyPiece =
    props.playingAs === (props.piece ? props.piece[1] : undefined);

  /* Events */
  const onDown = () => {
    if (props.location === undefined || !props.piece) return;

    if (holdingPiece === props.location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.PossibleMoves([]);
    } else if (props.piece[0] !== PieceType.none && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(props.location);
      Atoms.PossibleMoves(GetLegalMoves(board, props.location));
    }
  };

  return (
    props.piece[0] !== PieceType.none && (
      <>
        <Frame
          position={pos}
          size={new UDim2(1 / 8, 0, 1 / 8, 0)}
          noBackground
          zIndex={holdingPiece === props.location ? 100 : 3}
        >
          <textbutton
            Size={new UDim2(1, 0, 1, 0)}
            Text={""}
            BackgroundTransparency={1}
            ZIndex={1}
            Event={{
              MouseEnter: () => {
                offsetYMotion.spring(isMyPiece ? -10 : 0);
              },
              MouseLeave: () => {
                offsetYMotion.spring(0);
              },
              MouseButton1Down: onDown,
            }}
          />
          {image ? (
            <Image
              image={image}
              position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
              size={new UDim2(1, 0, 1, 0)}
              outlinePrecision={30}
              outlineThickness={px(4)}
              outlineStartAngle={40}
              outlineColor={new Color3(0.35, 0.35, 0.35)}
              zIndex={holdingPiece === props.location ? 100 : 3}
            />
          ) : undefined}
        </Frame>
      </>
    )
  );
}
