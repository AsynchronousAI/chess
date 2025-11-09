import { useEffect, useState } from "@rbxts/react";
import { Color, Piece } from "shared/board";
import { usePx } from "../usePx";
import { Players } from "@rbxts/services";
import { Frame, Image, Text } from "@rbxts/better-react-components";
import React from "@rbxts/react";
import { IconPack, Vector } from "./images";

const formatTime = (seconds: number) => {
  const minutes = math.floor(seconds / 60);
  const remaining = seconds % 60;
  const padded = remaining < 10 ? `0${remaining}` : `${remaining}`;
  return `${minutes}:${padded}`;
};
export function Player({
  userId,
  flag,
  rating,
  time,
  color,
  valueDifference,
  piecesTaken,
  iconPack,
}: {
  userId: number;
  flag: string;
  rating: number;
  time: number;
  color: Color;
  valueDifference: number;
  piecesTaken: Piece[];
  iconPack: IconPack;
}) {
  const px = usePx();
  const [name, setName] = useState("Loading..");
  const [thumbnail, setThumbnail] = useState("");

  useEffect(() => {
    if (userId > 0) {
      setName(Players.GetNameFromUserIdAsync(userId));
      const [content, _success] = Players.GetUserThumbnailAsync(
        userId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size420x420,
      );
      setThumbnail(content);
    } else if (userId < 0) {
      setName("Bot");
    }
  }, [userId]);

  return (
    <Frame size={new UDim2(0.85, 0, 0.05, 0)} noBackground>
      {/* Player details */}
      <Image
        noBackground
        visible={thumbnail !== ""}
        image={thumbnail}
        size={new UDim2(1, 0, 1, 0)}
        aspectRatio={1}
      />
      <Text
        noBackground
        richText
        text={`<b>${name}</b> <font color="rgb(128,128,128)">(${rating})</font> ${flag}`}
        size={new UDim2(0.85, 0, 0.45, 0)}
        position={new UDim2(0.085, 0, 0, 0)}
        textSize={px(18)}
        textAlign={"Left"}
        paddingLeft={px(2)}
        paddingTop={px(15)}
        paddingBottom={px(15)}
        textColor={new Color3(1, 1, 1)}
        font={"SourceSans"}
      />

      {/* Pieces */}
      <Frame
        size={new UDim2(1, 0, 0.5, 0)}
        noBackground
        position={new UDim2(0.085, 0, 0.55, 0)}
      >
        <uilistlayout
          VerticalAlignment={"Center"}
          HorizontalAlignment={"Left"}
          FillDirection={"Horizontal"}
          Padding={new UDim(0, -px(5))}
        />
        {piecesTaken.map((piece, index) => (
          <Image
            key={index}
            image={iconPack[(1 - color) as Color][piece]}
            noBackground
            size={new UDim2(1, 0, 1, 0)}
            aspectRatio={1}
          />
        ))}

        {valueDifference > 0 ? (
          <Text
            text={`+${valueDifference}`}
            size={new UDim2(0.05, 0, 1, 0)}
            textSize={px(17)}
            noBackground
            textColor={new Color3(0.65, 0.65, 0.65)}
            font={"SourceSansSemibold"}
          />
        ) : undefined}
      </Frame>

      {/* Clock */}
      <Text
        size={new UDim2(0.2, 0, 1, 0)}
        position={new UDim2(0.8, 0, 0, 0)}
        text={formatTime(time)}
        background={"#403E39"}
        textSize={px(25)}
        textAlign={"Right"}
        paddingRight={px(10)}
        textColor={new Color3(1, 1, 1)}
        font={"SourceSansSemibold"}
      >
        <Image
          noBackground
          size={new UDim2(0.55, 0, 0.55, 0)}
          aspectRatio={1}
          image={"rbxassetid://10709805144"}
          anchorPoint={new Vector2(0, 0.5)}
          position={new UDim2(0.1, 0, 0.5, 0)}
        />
      </Text>
    </Frame>
  );
}
