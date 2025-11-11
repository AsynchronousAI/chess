import {
  Button,
  CanvasGroup,
  Frame,
  Image,
  Text,
} from "@rbxts/better-react-components";
import React, { useEffect, useState } from "@rbxts/react";
import { usePx } from "./usePx";
import { useAsyncEffect, useMotion } from "@rbxts/pretty-react-hooks";
import Atoms from "./atoms";

export interface EndgamePopupProps {
  title: string;
  description: string;
  rating: number;
  ratingChange: number;
  open: boolean;
}

const getEloChangeText = (rVal: number, rChange: number) => {
  const color =
    rChange > 0 ? "#78e876" : rChange < 0 ? "#e87a76" : "rgb(200,200,200)";
  const sign = rChange > 0 ? "+" : rChange < 0 ? "-" : "";
  const change = math.abs(rChange);

  return `<font color="${color}">${rVal} (${sign}${change})</font> elo`;
};

export function EndgamePopup(props: EndgamePopupProps) {
  const px = usePx();
  const [visualizedIncrement, setVisualizedIncrement] = useState(0);
  const [closeButtonTransparency, closeButtonMotion] = useMotion(0.5);
  const [position, positionMotion] = useMotion(new UDim2(0.5, 0, 1.5, 0));

  useEffect(() => {
    let cancelled = false;

    async function animate() {
      setVisualizedIncrement(0);

      await Promise.delay(0.5);
      if (props.ratingChange === 0) return;

      const step = props.ratingChange > 0 ? 1 : -1;
      const target = props.ratingChange;

      for (let i = 0; i !== target; i += step) {
        if (cancelled) break;
        setVisualizedIncrement(i + step);
        print(i + step);
        await Promise.delay(5 / 100);
      }
    }

    animate();
    return () => {
      cancelled = true;
    };
  }, [props.ratingChange]);

  useEffect(() => {
    positionMotion.spring(
      props.open ? new UDim2(0.5, 0, 0.5, 0) : new UDim2(0.5, 0, 1.5, 0),
    );
  }, [props.open]);

  const infoText = getEloChangeText(
    props.rating + visualizedIncrement,
    props.ratingChange,
  );

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
        size={new UDim2(1, 0, 0.1, 0)}
        textSize={px(30)}
        font={"SourceSansBold"}
        noBackground
        textColor={new Color3(1, 1, 1)}
      />
      <Text
        text={props.description}
        position={new UDim2(0, 0, 0.125, 0)}
        size={new UDim2(1, 0, 0.1, 0)}
        textSize={px(16)}
        font={"SourceSansSemibold"}
        noBackground
        textColor={new Color3(0.7, 0.7, 0.7)}
      />
      <Text
        text={infoText}
        richText
        position={new UDim2(0, 0, 0.875, 0)}
        size={new UDim2(1, 0, 0.1, 0)}
        textSize={px(16)}
        font={"SourceSansSemibold"}
        noBackground
        textColor={new Color3(0.7, 0.7, 0.7)}
      />

      <Frame
        size={new UDim2(0.075, 0, 0.075, 0)}
        position={new UDim2(0.91, 0, 0.01, 0)}
        noBackground
      >
        <Image
          size={new UDim2(1, 0, 1, 0)}
          image={"rbxassetid://10747384394"}
          noBackground
          imageTransparency={closeButtonTransparency}
        />
        <textbutton
          Size={new UDim2(1, 0, 1, 0)}
          Text={""}
          BackgroundTransparency={1}
          Event={{
            MouseEnter: () =>
              closeButtonMotion.spring(0.25, { frequency: 0.15 }),
            MouseLeave: () =>
              closeButtonMotion.spring(0.5, { frequency: 0.15 }),
            MouseButton1Click: () =>
              Atoms.Popup((p) => ({ ...p, open: false })),
          }}
        />
      </Frame>

      <Button
        size={new UDim2(0.8, 0, 0.2, 0)}
        position={new UDim2(0.5, 0, 0.45, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        text={"New Game"}
        textColor={new Color3(0.95, 0.95, 0.95)}
        background={"#3C3A38"}
        font={"SourceSansSemibold"}
        autoButtonColor={false}
        textSize={px(24)}
        cornerRadius={px(5)}
      />
      <Button
        size={new UDim2(0.8, 0, 0.2, 0)}
        position={new UDim2(0.5, 0, 0.7, 0)}
        anchorPoint={new Vector2(0.5, 0.5)}
        text={"Rematch"}
        textColor={new Color3(0.95, 0.95, 0.95)}
        background={"#3C3A38"}
        font={"SourceSansSemibold"}
        autoButtonColor={false}
        textSize={px(24)}
        cornerRadius={px(5)}
      />
    </CanvasGroup>
  );
}
