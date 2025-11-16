import { OnStart, Service } from "@flamework/core";
import { t } from "@rbxts/t";
import { Players } from "@rbxts/services";
import { Event } from "shared/lifecycles";
import { createCollection } from "@rbxts/lapis";
import { Color } from "shared/board";

const playerStore = createCollection("players3", {
  defaultData: {
    rating: {
      elo: 1500,
      rd: 350,
      vol: 0.06,
    },
    opponents: [],
  },
  validate: t.strictInterface({
    rating: t.strictInterface({
      elo: t.number,
      rd: t.number,
      vol: t.number,
    }),
    opponents: t.array(
      t.strictInterface({
        elo: t.number,
        rd: t.number,
        score: t.union(t.literal(0), t.literal(0.5), t.literal(1)),

        /* Metadata */
        gameId: t.string,
        user: t.number,
        myRating: t.number,
        moves: t.number,
        date: t.number,
      }),
    ),
  }),
});
const gameStore = createCollection("games", {
  defaultData: {
    /* Minified version of src/server/services/gameplay.ts#L16 */
    player1: 0, // userid
    player2: 0,

    /* Elo */
    player1elo: 100,
    player2elo: 100,

    /* Roles */
    winner: 3, // either 1 or 2 for player, 0 for none, 3 for draw.
    color: Color.white, // represents player1 color.

    /* board */
    opening: "",
    moves: [],
  },
  validate: t.strictInterface({
    player1: t.number,
    player2: t.number,
    player1elo: t.number,
    player2elo: t.number,
    winner: t.number,
    color: t.union(t.literal(Color.white), t.literal(Color.black)),
    opening: t.string,
    moves: t.array(t.strictArray(t.number, t.number, t.optional(t.number))),
  }),
});

class TotalMap<K, V> {
  private map = new Map<K, V>();

  get(key: K): V {
    while (!this.map.has(key)) task.wait();
    return this.map.get(key)!;
  }

  set(key: K, value: V) {
    this.map.set(key, value);
  }

  delete(key: K) {
    this.map.delete(key);
  }
}
@Service()
export class Datastore implements OnStart {
  public players = new TotalMap<
    Player,
    Awaited<ReturnType<typeof playerStore.load>>
  >();
  public games = gameStore;

  @Event(Players.PlayerAdded)
  onPlayer(player: Player) {
    playerStore
      .load(`${player.UserId}`, [player.UserId])
      .andThen((document) => {
        this.players.set(player, document);
      })
      .catch((err) => {
        warn(`Failed to load player data for ${player.UserId}: ${err}`);
        player.Kick("Failed to load player data");
      });
  }
  @Event(Players.PlayerRemoving)
  onPlayerLeave(player: Player) {
    this.players.get(player)?.close().catch(warn);
    this.players.delete(player);
  }
  onStart(): void {
    for (const player of Players.GetPlayers()) {
      this.onPlayer(player);
    }
  }
}
/*
// Update data
store.updateAsync(player, (data) => {
  data.coins += 100;
  return true;
});

// Atomic transactions
store.txAsync([player1, player2], (state) => {
  const amount = 50;
  state.get(player1).coins -= amount;
  state.get(player2).coins += amount;
  return true;
});
 */
