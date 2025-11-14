import { OnStart, Service } from "@flamework/core";
import { t } from "@rbxts/t";
import { Players } from "@rbxts/services";
import { Event } from "shared/lifecycles";
import { createCollection } from "@rbxts/lapis";

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

const playerStore = createCollection("players", {
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
        gameId: t.string,
      }),
    ),
  }),
});

@Service()
export class Datastore implements OnStart {
  public players = new TotalMap<
    Player,
    Awaited<ReturnType<typeof playerStore.load>>
  >();

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
