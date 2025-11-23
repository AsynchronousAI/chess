import React, { useEffect } from "@rbxts/react";
import { Color, Piece as PieceType } from "shared/board";
import { useAtom } from "@rbxts/react-charm";
import { Frame } from "@rbxts/better-react-components";
import { default as GetLegalMoves } from "shared/engine/legalMoves";
import { useMotion, useMouse } from "@rbxts/pretty-react-hooks";
import { generatePosition } from "./shared";
import { IconPack } from "./images";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import Atoms from "../atoms";
import { usePx } from "../hooks/usePx";
import { Image } from "../components/image";

export interface PieceProps {
  pos: [number, number];
  location: number;
  iconPack: IconPack;
  playingAs: Color;
  piece: [PieceType, Color];
  onRelease: () => void;
  locked: boolean;

  containerRef: React.MutableRefObject<Frame | undefined>;
}
export function Piece(props: PieceProps) {
  const gameplay = useFlameworkDependency<Gameplay>();
  const board = gameplay.useBoard();
  const holdingPiece = useAtom(Atoms.HoldingPiece);
  const dragging = useAtom(Atoms.Dragging);

  const px = usePx();

  const mousePos = useMouse()
    .map((v) => v.sub(props.containerRef.current?.AbsolutePosition!))
    .map((v) => new UDim2(0, v.X, 0, v.Y));

  const [offsetY, offsetYMotion] = useMotion(0);
  const [rotation, rotationMotion] = useMotion(0);

  const [pos, posMotion] = useMotion(
    generatePosition(props.pos, props.playingAs),
  );
  useEffect(() => {
    const generated = generatePosition(props.pos, props.playingAs);
    if (generated === pos.getValue()) return;

    posMotion.tween(generated, {
      style: Enum.EasingStyle.Quint,
      time: 0.2,
    });
    /*rotationMotion.tween(20, {
      time: 0.1,
    });
    task.delay(0.1, () => {
      rotationMotion.tween(0, {
        time: 0.1,
      });
    });*/
  }, [props.pos]);

  /* Block data */
  const image = props.piece
    ? props.iconPack[props.piece[1]][props.piece[0]]
    : undefined;
  const isMyPiece =
    props.playingAs === (props.piece ? props.piece[1] : undefined);

  /* Events */
  const onDown = () => {
    if (
      gameplay.locked ||
      Atoms.ViewingPlayer() > 0 ||
      props.locked ||
      props.location === undefined ||
      !props.piece
    ) {
      Atoms.Dragging(false);
      return;
    }

    if (holdingPiece === props.location) {
      // drop
      Atoms.HoldingPiece(undefined);
      Atoms.Dragging(false);
      Atoms.PossibleMoves([]);
    } else if (props.piece[0] !== PieceType.none && isMyPiece) {
      // pick up
      Atoms.HoldingPiece(props.location);
      Atoms.Dragging(true);
      Atoms.PossibleMoves(
        GetLegalMoves(board, props.location, true, props.playingAs),
      );
    }
  };

  return (
    props.piece[0] !== PieceType.none && (
      <Frame
        position={dragging && holdingPiece === props.location ? mousePos : pos}
        size={new UDim2(1 / 8, 0, 1 / 8, 0)}
        overrideRoblox={{ Rotation: rotation }}
        noBackground
        anchorPoint={
          dragging && holdingPiece === props.location
            ? new Vector2(0.5, 1)
            : undefined
        }
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
            MouseButton1Up: props.onRelease, // mouse released on piece
          }}
        />
        {image ? (
          <Image
            image={image}
            position={offsetY.map((y) => new UDim2(0, 0, 0, y))}
            size={new UDim2(1, 0, 1, 0)}
            outlinePrecision={30}
            outlineThickness={px(3)}
            outlineStartAngle={40}
            outlineColor={new Color3(0.35, 0.35, 0.35)}
            zIndex={holdingPiece === props.location ? 100 : 3}
          />
        ) : undefined}
      </Frame>
    )
  );
}
