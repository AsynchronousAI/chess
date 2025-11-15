import {
  createBinarySerializer,
  DataType,
} from "@rbxts/flamework-binary-serializer";

interface PlayerData {
  rating: {
    elo: DataType.u8;
    rd: DataType.f32;
    vol: DataType.f32;
  };
  opponents: {
    elo: DataType.u8;
    rd: DataType.f32;
    score: 0 | 0.5 | 2;
    gameId: string;
  }[];
}
interface GameData {
  player1: DataType.u32 | -1;
  player2: DataType.u32 | -1;

  player1elo: DataType.u8;
  player2elo: DataType.u8;

  winner: DataType.u8;
  color: 0 | 1;

  moves: [DataType.u8, DataType.u8, DataType.u8 | undefined][];
}

export const PlayerSerializer = createBinarySerializer<PlayerData>();
export const GameSerializer = createBinarySerializer<GameData>();
