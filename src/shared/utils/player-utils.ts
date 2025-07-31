import { Players } from "@rbxts/services";
import { promiseTree } from "@rbxts/validate-tree";

const characterSchema = {
	$className: "Model",
	Humanoid: {
		$className: "Humanoid",
		Animator: "Animator",
	},
	HumanoidRootPart: "BasePart",
} as const;

export interface Character extends Model {
	Humanoid: Humanoid & {
		Animator: Animator;
	};
	HumanoidRootPart: BasePart;
}

export async function promiseCharacter(character: Model): Promise<Character> {
	return promiseTree(character, characterSchema).timeout(30, "Character timed out");
}

export async function promisePlayerDisconnected(player: Player): Promise<void> {
	if (!player.IsDescendantOf(Players)) {
		return;
	}

	await Promise.fromEvent(Players.PlayerRemoving, (playerWhoLeft) => playerWhoLeft === player);
}

export function getPlayerByName(name: string) {
	const player = Players.FindFirstChild(name);

	if (player?.IsA("Player")) {
		return player;
	}
}

export function onPlayerAdded(callback: (player: Player) => void) {
	const connection = Players.PlayerAdded.Connect(callback);

	for (const player of Players.GetPlayers()) {
		callback(player);
	}

	return () => {
		connection.Disconnect();
	};
}
