import { OnStart, Service } from "@flamework/core";
import { t } from "@rbxts/t";
import Lyra from "@rbxts/lyra";
import { Players } from "@rbxts/services";
import { Event } from "shared/lifecycles";

const store = Lyra.createPlayerStore({
  name: "players",
  template: {
    rating: {
      rating: 1500,
      rd: 350,
      vol: 0.06,
    },
    opponents: [],
  },
  schema: t.strictInterface({
    rating: t.strictInterface({
      rating: t.number,
      rd: t.number,
      vol: t.number,
    }),
    opponents: t.array(
      t.strictInterface({
        rating: t.number,
        rd: t.number,
        score: t.union(t.literal(0), t.literal(0.5), t.literal(1)),
        gameId: t.string,
      }),
    ),
  }),
});

@Service()
export class Datastore implements OnStart {
  public readonly playerStore = store;

  @Event(Players.PlayerAdded)
  onPlayer(player: Player) {
    store.loadAsync(player);
  }
  @Event(Players.PlayerRemoving)
  onPlayerLeave(player: Player) {
    store.unloadAsync(player);
  }
  onStart(): void {
    for (const player of Players.GetPlayers()) {
      this.onPlayerLeave(player);
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
