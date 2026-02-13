import React, { useEffect } from "@rbxts/react";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "./hooks/usePx";
import Atoms from "./atoms";

export interface ConfirmationPopupProps {
  title: string;
  description: string;
  open: boolean;
  onConfirm?: () => void;
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
    <frame
      Size={new UDim2(0.4, 0.0, 0.4, 0)}
      AnchorPoint={new Vector2(0.5, 0.5)}
      Position={position}
      BackgroundColor3={Color3.fromHex("#262421")}
      BorderSizePixel={0}
    >
      <uiaspectratioconstraint AspectRatio={0.9} />
      <uicorner CornerRadius={new UDim(0, px(8))} />
      <uistroke Color={Color3.fromHex("#3C3A38")} Transparency={0.5} />
      <frame
        Size={new UDim2(1, 0, 0.235, 0)}
        BackgroundColor3={Color3.fromHex("#3C3A38")}
        BorderSizePixel={0}
      />
      <textlabel
        Text={props.title}
        Position={new UDim2(0, 0, 0, 0)}
        Size={
          props.description
            ? new UDim2(1, 0, 0.15, 0)
            : new UDim2(1, 0, 0.235, 0)
        }
        Font={Enum.Font.SourceSansBold}
        BackgroundTransparency={1}
        TextScaled={true}
        TextColor3={new Color3(1, 1, 1)}
      >
        <uipadding
          PaddingTop={new UDim(0.1, 0)}
          PaddingBottom={new UDim(0.1, 0)}
          PaddingLeft={new UDim(0.1, 0)}
          PaddingRight={new UDim(0.1, 0)}
        />
      </textlabel>
      <textlabel
        Text={props.description}
        Position={new UDim2(0, 0, 0.125, 0)}
        Size={new UDim2(1, 0, 0.1, 0)}
        TextScaled={true}
        Font={Enum.Font.SourceSansSemibold}
        BackgroundTransparency={1}
        TextColor3={new Color3(0.7, 0.7, 0.7)}
      >
        <uipadding
          PaddingTop={new UDim(0.1, 0)}
          PaddingBottom={new UDim(0.1, 0)}
          PaddingLeft={new UDim(0.1, 0)}
          PaddingRight={new UDim(0.1, 0)}
        />
      </textlabel>

      <textbutton
        Size={new UDim2(0.8, 0, 0.2, 0)}
        Position={new UDim2(0.5, 0, 0.5, 0)}
        AnchorPoint={new Vector2(0.5, 0.5)}
        Text={"Accept"}
        TextColor3={new Color3(0.95, 0.95, 0.95)}
        BackgroundColor3={Color3.fromHex("#3C3A38")}
        Font={Enum.Font.SourceSansSemibold}
        AutoButtonColor={false}
        TextScaled={true}
        BorderSizePixel={0}
        Event={{
          MouseButton1Click: () => {
            Atoms.ConfirmationPopup((x) => ({ ...x, open: false }));
            props.onConfirm?.();
          },
        }}
      >
        <uipadding
          PaddingTop={new UDim(0.2, 0)}
          PaddingBottom={new UDim(0.2, 0)}
          PaddingLeft={new UDim(0.2, 0)}
          PaddingRight={new UDim(0.2, 0)}
        />
        <uicorner CornerRadius={new UDim(0, px(5))} />
      </textbutton>
      <textbutton
        Size={new UDim2(0.8, 0, 0.2, 0)}
        Position={new UDim2(0.5, 0, 0.75, 0)}
        AnchorPoint={new Vector2(0.5, 0.5)}
        Text={"Decline"}
        TextColor3={new Color3(0.95, 0.95, 0.95)}
        BackgroundColor3={Color3.fromHex("#3C3A38")}
        Font={Enum.Font.SourceSansSemibold}
        AutoButtonColor={false}
        TextScaled={true}
        BorderSizePixel={0}
        Event={{
          MouseButton1Click: () => {
            Atoms.ConfirmationPopup((x) => ({ ...x, open: false }));
            props.onCancel?.();
          },
        }}
      >
        <uipadding
          PaddingTop={new UDim(0.2, 0)}
          PaddingBottom={new UDim(0.2, 0)}
          PaddingLeft={new UDim(0.2, 0)}
          PaddingRight={new UDim(0.2, 0)}
        />
        <uicorner CornerRadius={new UDim(0, px(5))} />
      </textbutton>
    </frame>
  );
}
