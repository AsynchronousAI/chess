import React, { useEffect, useState } from "@rbxts/react";
import { Players, RunService } from "@rbxts/services";
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
  const gameplay = RunService.IsRunning()
    ? useFlameworkDependency<Gameplay>()
    : undefined;
  const px = usePx();
  const [p2Name, p2Thumbnail] = usePlayer(xGame.user);

  return (
    <textbutton
      Size={new UDim2(1, 0, 0, px(125))}
      BackgroundTransparency={1}
      Text=""
      LayoutOrder={-xGame.date}
      AutoButtonColor={false}
      BorderSizePixel={0}
      Event={{
        MouseButton1Click: () => gameplay && gameplay.loadGame(xGame.gameId),
      }}
    >
      <uipadding
        PaddingTop={new UDim(0, px(8))}
        PaddingBottom={new UDim(0, px(8))}
        PaddingLeft={new UDim(0, px(8))}
        PaddingRight={new UDim(0, px(8))}
      />
      <uistroke
        Color={Color3.fromHex("#262522")}
        Thickness={1}
        ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
      />
      <uilistlayout
        FillDirection={Enum.FillDirection.Horizontal}
        VerticalAlignment={Enum.VerticalAlignment.Center}
        HorizontalAlignment={Enum.HorizontalAlignment.Center}
        Padding={new UDim(0, px(5))}
      />

      {/* player 1 */}
      <frame
        Size={new UDim2(1, 0, 1, 0)}
        BackgroundTransparency={1}
        BorderSizePixel={0}
      >
        <uiaspectratioconstraint AspectRatio={1.3} />
        <imagelabel
          Image={p1Thumbnail}
          Size={new UDim2(0.7, 0, 0.7, 0)}
          AnchorPoint={new Vector2(0.5, 0.5)}
          Position={new UDim2(0.5, 0, 0.4, 0)}
          BackgroundColor3={Color3.fromHex("#403E39")}
          BorderSizePixel={0}
        >
          <uiaspectratioconstraint AspectRatio={1} />
          <uicorner CornerRadius={new UDim(0, px(5))} />
          <uistroke
            Color={new Color3(1, 1, 1)}
            Thickness={2}
            Transparency={xGame.score === 1 ? 0.5 : 0.75}
          />
        </imagelabel>
        <textlabel
          Text={`${p1Name} <font color="rgb(128,128,128)">(${xGame.myRating})</font>`}
          Font={Enum.Font.SourceSansSemibold}
          RichText={true}
          TextSize={px(15)}
          Size={new UDim2(1, 0, 0.25, 0)}
          Position={new UDim2(0, 0, 0.75, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(1, 1, 1)}
        />
      </frame>

      {/* player 2  */}
      <frame
        Size={new UDim2(1, 0, 1, 0)}
        BackgroundTransparency={1}
        BorderSizePixel={0}
      >
        <uiaspectratioconstraint AspectRatio={1.3} />
        <imagelabel
          Image={p2Thumbnail}
          Size={new UDim2(0.7, 0, 0.7, 0)}
          AnchorPoint={new Vector2(0.5, 0.5)}
          Position={new UDim2(0.5, 0, 0.4, 0)}
          BackgroundColor3={Color3.fromHex("#403E39")}
          BorderSizePixel={0}
        >
          <uiaspectratioconstraint AspectRatio={1} />
          <uicorner CornerRadius={new UDim(0, px(5))} />
          <uistroke
            Color={new Color3(1, 1, 1)}
            Thickness={2}
            Transparency={xGame.score === 0 ? 0.5 : 0.75}
          />
        </imagelabel>
        <textlabel
          Text={`${p2Name} <font color="rgb(128,128,128)">(${xGame.theirRating})</font>`}
          Font={Enum.Font.SourceSansSemibold}
          RichText={true}
          TextSize={px(16)}
          Size={new UDim2(1, 0, 0.25, 0)}
          Position={new UDim2(0, 0, 0.75, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(1, 1, 1)}
        />
      </frame>

      <frame
        Size={new UDim2(1, 0, 1, 0)}
        BackgroundTransparency={1}
        BorderSizePixel={0}
      >
        <uiaspectratioconstraint AspectRatio={2.4} />
        <uilistlayout
          FillDirection={Enum.FillDirection.Vertical}
          VerticalAlignment={Enum.VerticalAlignment.Center}
          HorizontalAlignment={Enum.HorizontalAlignment.Center}
          Padding={new UDim(0, px(5))}
        />

        {/* Moves */}
        <textlabel
          Text={`${math.floor(xGame.moves / 2)} moves`}
          Font={Enum.Font.SourceSansSemibold}
          TextSize={px(18)}
          Size={new UDim2(0.8, 0, 0.25, 0)}
          Position={new UDim2(0.15, 0, 0.25, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(0.65, 0.65, 0.65)}
          TextXAlignment={Enum.TextXAlignment.Left}
        >
          <imagelabel
            Size={new UDim2(0.8, 0, 0.8, 0)}
            Position={new UDim2(-0.1, 0, 0.5, 0)}
            AnchorPoint={new Vector2(0.5, 0.5)}
            BackgroundTransparency={1}
            ImageColor3={new Color3(0.5, 0.5, 0.5)}
            Image={"rbxassetid://10709768019"}
          >
            <uiaspectratioconstraint AspectRatio={1} />
          </imagelabel>
        </textlabel>

        {/* Date */}
        <textlabel
          Text={DateTime.fromUnixTimestamp(xGame.date).FormatLocalTime(
            "LL",
            "en-us",
          )}
          Font={Enum.Font.SourceSansSemibold}
          TextSize={px(18)}
          Size={new UDim2(0.8, 0, 0.25, 0)}
          Position={new UDim2(0.15, 0, 0.5, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(0.65, 0.65, 0.65)}
          TextXAlignment={Enum.TextXAlignment.Left}
        >
          <imagelabel
            Size={new UDim2(0.8, 0, 0.8, 0)}
            Position={new UDim2(-0.1, 0, 0.5, 0)}
            AnchorPoint={new Vector2(0.5, 0.5)}
            BackgroundTransparency={1}
            ImageColor3={new Color3(0.5, 0.5, 0.5)}
            Image={"rbxassetid://10709789505"}
          >
            <uiaspectratioconstraint AspectRatio={1} />
          </imagelabel>
        </textlabel>

        {/* Opening
        <textlabel
          Text={"Queen's Gambit: Accepted"}
          Font={Enum.Font.SourceSansSemibold}
          TextSize={px(18)}
          Size={new UDim2(0.8, 0, 0.25, 0)}
          Position={new UDim2(0.15, 0, 0.5, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(0.65, 0.65, 0.65)}
          TextXAlignment={Enum.TextXAlignment.Left}
        >
          <imagelabel
            Size={new UDim2(0.8, 0, 0.8, 0)}
            Position={new UDim2(-0.1, 0, 0.5, 0)}
            AnchorPoint={new Vector2(0.5, 0.5)}
            BackgroundTransparency={1}
            ImageColor3={new Color3(0.5, 0.5, 0.5)}
            Image={"rbxassetid://10709781824"}
          >
            <uiaspectratioconstraint AspectRatio={1} />
          </imagelabel>
        </textlabel> */}
      </frame>

      {/* Win / lose indicator */}
      <textlabel
        Text={xGame.score === 1 ? "1\n0" : xGame.score === 0 ? "0\n1" : "½\n½"}
        Font={Enum.Font.SourceSansSemibold}
        TextSize={px(20)}
        Size={new UDim2(0.05, 0, 0.5, 0)}
        Position={new UDim2(0, 0, 0.5, 0)}
        BackgroundTransparency={1}
        TextColor3={new Color3(0.5, 0.5, 0.5)}
      />
      <frame
        Size={new UDim2(0, px(25), 0, px(25))}
        BackgroundColor3={
          xGame.score === 1
            ? Color3.fromHex("#81B64C")
            : xGame.score === 0
              ? Color3.fromHex("#F6412E")
              : Color3.fromHex("#909090")
        }
        BorderSizePixel={0}
      >
        <uicorner CornerRadius={new UDim(0, px(4))} />
        <imagelabel
          Size={new UDim2(0.8, 0, 0.8, 0)}
          Position={new UDim2(0.5, 0, 0.5, 0)}
          AnchorPoint={new Vector2(0.5, 0.5)}
          BackgroundTransparency={1}
          ImageColor3={Color3.fromHex("#262522")}
          Image={
            xGame.score === 1
              ? "rbxassetid://10734924532"
              : xGame.score === 0
                ? "rbxassetid://10734896206"
                : "rbxassetid://10723345990"
          }
        />
      </frame>
    </textbutton>
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
    <canvasgroup
      Size={new UDim2(0.5, 0, 0.9, 0)}
      BackgroundColor3={new Color3(0.1, 0.1, 0.1)}
      Position={new UDim2(0.5, 0, 0.5, 0)}
      AnchorPoint={new Vector2(0.5, 0.5)}
      BorderSizePixel={0}
    >
      <uicorner CornerRadius={new UDim(0, px(8))} />
      <uistroke Color={new Color3(0.25, 0.25, 0.25)} Thickness={px(0.5)} />
      <frame
        Size={new UDim2(1, 0, 0.1, 0)}
        BackgroundColor3={Color3.fromHex("#262522")}
        BorderSizePixel={0}
      >
        <uistroke Color={new Color3(0.5, 0.5, 0.5)} Thickness={px(0.5)} />
        <textlabel
          Text={`${p1Name}'s games`}
          Font={Enum.Font.SourceSansBold}
          TextScaled={true}
          Size={new UDim2(1, 0, 1, 0)}
          BackgroundTransparency={1}
          TextColor3={new Color3(1, 1, 1)}
          TextXAlignment={Enum.TextXAlignment.Left}
        >
          <uipadding
            PaddingTop={new UDim(0.25, 0)}
            PaddingBottom={new UDim(0.25, 0)}
            PaddingRight={new UDim(0.25, 0)}
            PaddingLeft={new UDim(0.05, 0)}
          />
        </textlabel>

        <frame
          Size={new UDim2(0.5, 0, 0.5, 0)}
          Position={new UDim2(1, -px(25), 0.5, 0)}
          AnchorPoint={new Vector2(0.5, 0.5)}
          BackgroundTransparency={1}
          BorderSizePixel={0}
        >
          <uiaspectratioconstraint AspectRatio={1} />
          <imagelabel
            Size={new UDim2(1, 0, 1, 0)}
            Image={"rbxassetid://10747384394"}
            BackgroundTransparency={1}
            ImageTransparency={closeButtonTransparency}
          />
          <textbutton
            Size={new UDim2(1, 0, 1, 0)}
            Text=""
            BackgroundTransparency={1}
            Event={{
              MouseEnter: () =>
                closeButtonMotion.spring(0.25, { frequency: 0.15 }),
              MouseLeave: () =>
                closeButtonMotion.spring(0.5, { frequency: 0.15 }),
              MouseButton1Click: () => Atoms.ViewingPlayer(0),
            }}
          />
        </frame>
      </frame>

      {/* List */}
      <scrollingframe
        BackgroundTransparency={1}
        Size={new UDim2(1, 0, 0.9, 0)}
        Position={new UDim2(0, 0, 0.1, 0)}
        ScrollingDirection={Enum.ScrollingDirection.Y}
        ScrollBarImageTransparency={0.8}
        ScrollBarThickness={8}
        CanvasSize={new UDim2(1, 0, 0, px(100) * games.size())}
        BorderSizePixel={0}
      >
        <uilistlayout
          FillDirection={Enum.FillDirection.Vertical}
          VerticalAlignment={Enum.VerticalAlignment.Top}
          HorizontalAlignment={Enum.HorizontalAlignment.Center}
          SortOrder={Enum.SortOrder.LayoutOrder}
        />

        {games.map((xGame) => (
          <PlayerListItem
            key={xGame.gameId}
            xGame={xGame}
            p1Name={p1Name}
            p1Thumbnail={p1Thumbnail}
          />
        ))}
      </scrollingframe>
    </canvasgroup>
  );
}
