import { OnStart, Service } from "@flamework/core";
import { Object } from "@rbxts/luau-polyfill";
import { HttpService, Players } from "@rbxts/services";
import { DataStoreService } from "@rbxts/services";
import { OpponentRating, PlayerRating } from "server/glicko2";
import { Event } from "shared/lifecycles";

/* Types */
type PlayerIdentifier = string;

type CallbackData = Record<
  keyof DatastoresProps,
  Array<(val: DatastoresProps[keyof DatastoresProps]) => void>
>;

/* Functions + Constants */
const MAX_LOAD_TIME = 5;

/** Datastore */
export interface DatastoresProps {
  rating: PlayerRating;
  opponents: Array<OpponentRating>;
}

const template: DatastoresProps = {
  rating: {
    rating: 1500,
    rd: 350,
    vol: 0.06,
  },
  opponents: [],
};

@Service()
export class Datastores implements OnStart {
  private cache: Record<PlayerIdentifier, DatastoresProps> = {};
  private datastores = {} as Record<keyof DatastoresProps, DataStore>;
  private callbacks: Record<PlayerIdentifier, CallbackData> = {};

  private getUserKey(player: Player): PlayerIdentifier {
    return tostring(player.UserId) + "d";
  }

  private async yieldForPlayerDatastore(
    player: Player,
    key: keyof DatastoresProps,
  ) {
    const startTime = os.clock();
    while (
      this.cache[this.getUserKey(player)]?.[key] === undefined &&
      os.clock() - startTime < MAX_LOAD_TIME
    )
      task.wait();
  }

  private async yieldForCallbacks(player: Player) {
    const startTime = os.clock();
    while (
      this.callbacks[this.getUserKey(player)] === undefined &&
      os.clock() - startTime < MAX_LOAD_TIME
    )
      task.wait();
  }

  /* API */
  public async get<T extends keyof DatastoresProps>(
    player: Player,
    key: T,
  ): Promise<DatastoresProps[T]> {
    await this.yieldForPlayerDatastore(player, key);

    const cached = this.cache[this.getUserKey(player)]?.[key];
    if (cached !== undefined) return cached;
    warn(
      `[DATASTORES] ${player.UserId}'s ${key} took too long to load! Using default values.`,
    );

    return template[key] as unknown as DatastoresProps[T];
  }

  public async set<T extends keyof DatastoresProps>(
    player: Player,
    key: T,
    value: DatastoresProps[T],
  ) {
    this.cache[this.getUserKey(player)][key] = value;

    for (const callback of this.callbacks[this.getUserKey(player)][key] ?? []) {
      callback(value);
    }
  }

  public async increment<T extends keyof DatastoresProps>(
    player: Player,
    key: T,
    amount: number,
  ) {
    const current = await this.get(player, key);
    if (typeIs(current, "number")) {
      await this.set(
        player,
        key,
        (current + amount) as unknown as DatastoresProps[T],
      );
    }
    return await this.get(player, key);
  }

  public async bind(
    player: Player,
    key: keyof DatastoresProps,
    callback: (val: DatastoresProps[keyof DatastoresProps]) => void,
  ) {
    await this.yieldForCallbacks(player);
    const userKey = this.getUserKey(player);
    this.callbacks[userKey][key] ??= [];
    this.callbacks[userKey][key].push(callback);
  }

  /* Events (load player data + save) */
  @Event(Players.PlayerAdded)
  load(player: Player) {
    const userKey = this.getUserKey(player);
    let currentCache: Record<string, unknown> = {};

    this.callbacks[userKey] = {} as CallbackData;

    for (const key of Object.keys(template)) {
      const k = key as keyof DatastoresProps;

      /* get the datastore */
      if (!this.datastores[k]) {
        this.datastores[k] = DataStoreService.GetDataStore(k);
      }

      const ds = this.datastores[k];

      /* load the value */
      const [datastoreValue, info] = ds.GetAsync(userKey) as LuaTuple<
        [string | undefined, DataStoreKeyInfo]
      >;
      const currentValue =
        datastoreValue && HttpService.JSONDecode(datastoreValue);

      currentCache[key] = currentValue ?? template[k];
    }

    this.cache[userKey] = currentCache as unknown as DatastoresProps;
  }

  @Event(Players.PlayerRemoving)
  save(player: Player) {
    const userKey = this.getUserKey(player);
    const currentCache = this.cache[userKey];

    for (const key of Object.keys(template)) {
      const k = key as keyof DatastoresProps;
      const datastore = this.datastores[k];

      /* save the value */
      const value = currentCache[k];
      const json = HttpService.JSONEncode(value);
      datastore.SetAsync(userKey, json);
    }
  }

  onStart() {
    game.BindToClose(() => {
      for (const player of Players.GetPlayers()) {
        this.save(player);
      }
    });
  }
}
