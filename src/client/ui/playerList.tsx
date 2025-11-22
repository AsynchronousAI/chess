import {
  Button,
  CanvasGroup,
  Frame,
  Image,
  ListLayout,
  ScrollingFrame,
  Text,
} from "@rbxts/better-react-components";
import React, { useEffect, useState } from "@rbxts/react";
import { Players } from "@rbxts/services";
import { Functions } from "client/network";
import { usePx } from "./hooks/usePx";
import { usePlayer } from "./hooks/usePlayer";
import { useMotion } from "@rbxts/pretty-react-hooks";
import Atoms from "./atoms";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";

interface PlayerListProps {
  player: number;
}
function PlayerListItem({
  xGame,
  p1Name,
  p1Thumbnail,
}: {
  xGame: Awaited<ReturnType<typeof Functions.ListPlayerGames.invoke>>[number];
  p1Name: string;
  p1Thumbnail: string;
}) {
  const gameplay = useFlameworkDependency<Gameplay>();
  const px = usePx();
  const [p2Name, p2Thumbnail] = usePlayer(xGame.user);

  return (
    <Button
      size={new UDim2(1, 0, 0, px(100))}
      noBackground
      cornerRadius={px(4)}
      padding={px(8)}
      aspectRatio={1.3 + 1.3 + 2 + 0.7}
      layoutOrder={-xGame.date}
      stroke={{
        Color: Color3.fromHex("#262522"),
        Thickness: 1,
        ApplyStrokeMode: "Border",
      }}
      overrideRoblox={{
        Event: { MouseButton1Click: () => gameplay.loadGame(xGame.gameId) },
      }}
    >
      <ListLayout
        direction={"Horizontal"}
        verticalAlign={"Center"}
        horizontalAlign={"Center"}
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
          image={p2Thumbnail}
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
          text={`${p2Name} <font color="rgb(128,128,128)">(${xGame.theirRating})</font>`}
          font={"SourceSansSemibold"}
          richText
          textSize={px(16)}
          size={new UDim2(1, 0, 0.25, 0)}
          position={new UDim2(0, 0, 0.75, 0)}
          noBackground
          textColor={new Color3(1, 1, 1)}
        />
      </Frame>

      <Frame size={new UDim2(1, 0, 1, 0)} aspectRatio={2.4} noBackground>
        <ListLayout
          direction={"Vertical"}
          verticalAlign={"Center"}
          horizontalAlign={"Center"}
          padding={px(5)}
        />

        {/* Moves */}
        <Text
          text={`${math.floor(xGame.moves / 2)} moves`}
          font={"SourceSansSemibold"}
          textSize={px(18)}
          size={new UDim2(0.8, 0, 0.25, 0)}
          position={new UDim2(0.15, 0, 0.25, 0)}
          noBackground
          textColor={new Color3(0.65, 0.65, 0.65)}
          textAlign={"Left"}
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
          textSize={px(18)}
          size={new UDim2(0.8, 0, 0.25, 0)}
          position={new UDim2(0.15, 0, 0.5, 0)}
          noBackground
          textColor={new Color3(0.65, 0.65, 0.65)}
          textAlign={"Left"}
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

        {/* Opening
        <Text
          text={"Queen's Gambit: Accepted"}
          font={"SourceSansSemibold"}
          textSize={px(18)}
          size={new UDim2(0.8, 0, 0.25, 0)}
          position={new UDim2(0.15, 0, 0.5, 0)}
          noBackground
          textColor={new Color3(0.65, 0.65, 0.65)}
          textAlign={"Left"}
        >
          <Image
            size={new UDim2(0.8, 0, 0.8, 0)}
            position={new UDim2(-0.1, 0, 0.5, 0)}
            anchorPoint={new Vector2(0.5, 0.5)}
            noBackground
            aspectRatio={1}
            imageColor={new Color3(0.5, 0.5, 0.5)}
            image={"rbxassetid://10709781824"}
          />
        </Text> */}
      </Frame>

      {/* Win / lose indicator */}
      <Text
        text={xGame.score === 1 ? "1\n0" : xGame.score === 0 ? "0\n1" : "½\n½"}
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
    </Button>
  );
}
export default function PlayerList(props: PlayerListProps) {
  const px = usePx();
  const [closeButtonTransparency, closeButtonMotion] = useMotion(0.5);
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
      setGames(x);
    });
  }, [props.player]);

  return (
    <CanvasGroup
      size={new UDim2(0.35, 0, 0.8, 0)}
      background={new Color3(0.1, 0.1, 0.1)}
      position={new UDim2(0.5, 0, 0.5, 0)}
      anchorPoint={new Vector2(0.5, 0.5)}
      cornerRadius={px(8)}
      stroke={{
        Color: new Color3(0.25, 0.25, 0.25),
        Thickness: px(0.5),
      }}
    >
      <Frame
        size={new UDim2(1, 0, 0.1, 0)}
        background={"#262522"}
        stroke={{
          Color: new Color3(0.5, 0.5, 0.5),
          Thickness: px(0.5),
        }}
      >
        <Text
          text={`${p1Name}'s games`}
          font={"SourceSansBold"}
          textSize={px(20)}
          size={new UDim2(1, 0, 1, 0)}
          noBackground
          textColor={new Color3(1, 1, 1)}
          paddingLeft={px(10)}
          textAlign={"Left"}
        />

        <Frame
          size={new UDim2(0.5, 0, 0.5, 0)}
          position={new UDim2(1, -px(25), 0.5, 0)}
          anchorPoint={new Vector2(0.5, 0.5)}
          noBackground
          aspectRatio={1}
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
              MouseButton1Click: () => Atoms.ViewingPlayer(0),
            }}
          />
        </Frame>
      </Frame>

      {/* List */}
      <ScrollingFrame
        noBackground
        size={new UDim2(1, 0, 0.9, 0)}
        position={new UDim2(0, 0, 0.1, 0)}
        direction={"Y"}
        scrollbar={{ imageTransparency: 0.8 }}
        overrideRoblox={{ ScrollBarThickness: 8 }}
        canvasSize={new UDim2(1, 0, 0, px(100) * games.size())}
      >
        <ListLayout
          direction={"Vertical"}
          verticalAlign={"Top"}
          horizontalAlign={"Center"}
          order={"LayoutOrder"}
        />

        {games.map((xGame) => (
          <PlayerListItem
            key={xGame.gameId}
            xGame={xGame}
            p1Name={p1Name}
            p1Thumbnail={p1Thumbnail}
          />
        ))}
      </ScrollingFrame>
    </CanvasGroup>
  );
}
