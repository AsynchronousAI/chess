import { Frame, Image, ListLayout, Text } from "@rbxts/better-react-components";
import React, { useEffect, useState } from "@rbxts/react";
import { Players } from "@rbxts/services";
import { Functions } from "client/network";
import { usePx } from "./hooks/usePx";
import { usePlayer } from "./hooks/usePlayer";
import { Color } from "shared/board";

interface PlayerListProps {
  player: number;
}
export default function PlayerList(props: PlayerListProps) {
  const px = usePx();
  const [games, setGames] = useState<
    Awaited<ReturnType<typeof Functions.ListPlayerGames.invoke>>
  >([
    {
      date: 1763264910,
      theirRating: 3500,
      gameId: "{84c51082-1c88-40fd-bf56-0a78eda316e1}",
      moves: 4,
      myRating: 1500,
      score: 0.5,
      user: -1,
    },
  ]);
  const [p1Name, p1Thumbnail] = usePlayer(props.player);

  useEffect(() => {
    Functions.ListPlayerGames.invoke(
      Players.GetPlayerByUserId(props.player)!,
    ).then((x) => {
      print(x);
      setGames(x);
    });
  }, [props.player]);

  return (
    <Frame size={new UDim2(1, 0, 1, 0)} background={new Color3(0.1, 0.1, 0.1)}>
      <ListLayout
        padding={px(10)}
        direction={"Vertical"}
        verticalAlign={"Top"}
        horizontalAlign={"Center"}
      />

      {games.map((xGame) => (
        <Frame
          size={new UDim2(0.5, -px(25), 0, px(100))}
          background={"#262522"}
          cornerRadius={px(4)}
          padding={px(3)}
          aspectRatio={1.3 + 1.3 + 2 + 0.7}
        >
          <ListLayout
            direction={"Horizontal"}
            verticalAlign={"Center"}
            horizontalAlign={"Left"}
            padding={px(5)}
          />

          {/* player 1 */}
          <Frame size={new UDim2(1, 0, 1, 0)} aspectRatio={1.3} noBackground>
            <Image
              image={p1Thumbnail}
              size={new UDim2(0.7, 0, 0.7, 0)}
              anchorPoint={new Vector2(0.5, 0.5)}
              position={new UDim2(0.5, 0, 0.4, 0)}
              aspectRatio={1}
              background={"#403E39"}
              cornerRadius={px(5)}
              stroke={{
                Color: new Color3(1, 1, 1),
                Thickness: 2,
                Transparency: xGame.score === 1 ? 0.5 : 0.75,
              }}
            />
            <Text
              text={`${p1Name} <font color="rgb(128,128,128)">(${xGame.myRating})</font>`}
              font={"SourceSansSemibold"}
              richText
              textSize={px(15)}
              size={new UDim2(1, 0, 0.25, 0)}
              position={new UDim2(0, 0, 0.75, 0)}
              noBackground
              textColor={new Color3(1, 1, 1)}
            />
          </Frame>

          {/* player 2  */}
          <Frame size={new UDim2(1, 0, 1, 0)} aspectRatio={1.3} noBackground>
            <Image
              image={p1Thumbnail}
              size={new UDim2(0.7, 0, 0.7, 0)}
              anchorPoint={new Vector2(0.5, 0.5)}
              position={new UDim2(0.5, 0, 0.4, 0)}
              aspectRatio={1}
              background={"#403E39"}
              cornerRadius={px(5)}
              stroke={{
                Color: new Color3(1, 1, 1),
                Thickness: 2,
                Transparency: xGame.score === 0 ? 0.5 : 0.75,
              }}
            />
            <Text
              text={`${p1Name} <font color="rgb(128,128,128)">(${xGame.myRating})</font>`}
              font={"SourceSansSemibold"}
              richText
              textSize={px(16)}
              size={new UDim2(1, 0, 0.25, 0)}
              position={new UDim2(0, 0, 0.75, 0)}
              noBackground
              textColor={new Color3(1, 1, 1)}
            />
          </Frame>

          <Frame size={new UDim2(1, 0, 1, 0)} aspectRatio={2} noBackground>
            {/* Moves */}
            <Text
              text={`${xGame.moves} moves`}
              font={"SourceSansSemibold"}
              textSize={px(20)}
              size={new UDim2(0.8, 0, 0.25, 0)}
              position={new UDim2(0.15, 0, 0.25, 0)}
              noBackground
              textColor={new Color3(0.65, 0.65, 0.65)}
              align={"Left"}
            >
              <Image
                size={new UDim2(0.8, 0, 0.8, 0)}
                position={new UDim2(-0.1, 0, 0.5, 0)}
                anchorPoint={new Vector2(0.5, 0.5)}
                noBackground
                aspectRatio={1}
                imageColor={new Color3(0.5, 0.5, 0.5)}
                image={"rbxassetid://10709768019"}
              />
            </Text>

            {/* Date */}
            <Text
              text={DateTime.fromUnixTimestamp(xGame.date).FormatLocalTime(
                "LL",
                "en-us",
              )}
              font={"SourceSansSemibold"}
              textSize={px(20)}
              size={new UDim2(0.8, 0, 0.25, 0)}
              position={new UDim2(0.15, 0, 0.5, 0)}
              noBackground
              textColor={new Color3(0.65, 0.65, 0.65)}
              align={"Left"}
            >
              <Image
                size={new UDim2(0.8, 0, 0.8, 0)}
                position={new UDim2(-0.1, 0, 0.5, 0)}
                anchorPoint={new Vector2(0.5, 0.5)}
                noBackground
                aspectRatio={1}
                imageColor={new Color3(0.5, 0.5, 0.5)}
                image={"rbxassetid://10709789505"}
              />
            </Text>
          </Frame>

          {/* Win / lose indicator */}
          <Text
            text={
              xGame.score === 1 ? "1\n0" : xGame.score === 0 ? "0\n1" : "½\n½"
            }
            font={"SourceSansSemibold"}
            textSize={px(20)}
            size={new UDim2(0.05, 0, 0.5, 0)}
            position={new UDim2(0, 0, 0.5, 0)}
            noBackground
            textColor={new Color3(0.5, 0.5, 0.5)}
          />
          <Frame
            size={new UDim2(0, px(25), 0, px(25))}
            background={
              xGame.score === 1
                ? "#81B64C"
                : xGame.score === 0
                  ? "#F6412E"
                  : "#909090"
            }
            cornerRadius={px(4)}
          >
            <Image
              size={new UDim2(0.8, 0, 0.8, 0)}
              position={new UDim2(0.5, 0, 0.5, 0)}
              anchorPoint={new Vector2(0.5, 0.5)}
              noBackground
              imageColor={"#262522"}
              image={
                xGame.score === 1
                  ? "rbxassetid://10734924532"
                  : xGame.score === 0
                    ? "rbxassetid://10734896206"
                    : "rbxassetid://10723345990"
              }
            />
          </Frame>
        </Frame>
      ))}
    </Frame>
  );
}
