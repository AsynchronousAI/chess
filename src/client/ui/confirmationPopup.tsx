import {
  Button,
  CanvasGroup,
  Frame,
  Image,
  Text,
} from "@rbxts/better-react-components";
import React, { useEffect, useState } from "@rbxts/react";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "./hooks/usePx";
import Atoms from "./atoms";

export interface ConfirmationPopupProps {
  title: string;
  description: string;
  open: boolean;
  onConfirm: () => void;
  onCancel?: () => void;
}

export function ConfirmationPopup(props: ConfirmationPopupProps) {
  const px = usePx();
  const [closeButtonTransparency, closeButtonMotion] = useMotion(0.5);
  const [position, positionMotion] = useMotion(new UDim2(0.5, 0, 1.5, 0));
  useEffect(() => {
    positionMotion.spring(
      props.open ? new UDim2(0.5, 0, 0.5, 0) : new UDim2(0.5, 0, 1.5, 0),
    );
  }, [props.open]);

  return (
    <CanvasGroup
      size={new UDim2(0.4, 0.0, 0.4, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      position={position}
      aspectRatio={0.9}
      cornerRadius={px(8)}
      background={"#262421"}
      stroke={{ Color: Color3.fromHex("#3C3A38"), Transparency: 0.5 }}
    >
      <Frame size={new UDim2(1, 0, 0.235, 0)} background={"#3C3A38"} />
      <Text
        text={props.title}
        position={new UDim2(0, 0, 0.035, 0)}
        size={
          props.description ? new UDim2(1, 0, 0.1, 0) : new UDim2(1, 0, 0.15, 0)
        }
        textSize={px(30)}
        font={"SourceSansBold"}
        noBackground
        textColor={new Color3(1, 1, 1)}
      />
      <Text
        text={props.description}
        position={new UDim2(0, 0, 0.125, 0)}
        size={new UDim2(1, 0, 0.1, 0)}
        overrideRoblox={{ TextScaled: true }}
        font={"SourceSansSemibold"}
        noBackground
        textColor={new Color3(0.7, 0.7, 0.7)}
      />

      <Button
        size={new UDim2(0.8, 0, 0.2, 0)}
        position={new UDim2(0.5, 0, 0.45, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        text={"Accept"}
        textColor={new Color3(0.95, 0.95, 0.95)}
        background={"#3C3A38"}
        font={"SourceSansSemibold"}
        autoButtonColor={false}
        textSize={px(24)}
        cornerRadius={px(5)}
        overrideRoblox={{
          Event: {
            MouseButton1Click: () => {
              Atoms.ConfirmationPopup((x) => ({ ...x, open: false }));
              props.onConfirm();
            },
          },
        }}
      />
      <Button
        size={new UDim2(0.8, 0, 0.2, 0)}
        position={new UDim2(0.5, 0, 0.7, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        text={"Decline"}
        textColor={new Color3(0.95, 0.95, 0.95)}
        background={"#3C3A38"}
        font={"SourceSansSemibold"}
        autoButtonColor={false}
        textSize={px(24)}
        cornerRadius={px(5)}
        overrideRoblox={{
          Event: {
            MouseButton1Click: () => {
              Atoms.ConfirmationPopup((x) => ({ ...x, open: false }));
              props.onCancel?.();
            },
          },
        }}
      />
    </CanvasGroup>
  );
}
