import { RunService } from "@rbxts/services";

interface SchedulerOptions {
	readonly name: string;
	readonly onRender?: (deltaTime: number, alpha: number) => void;
	readonly onTick?: (deltaTime: number) => void;
	readonly phase?: number;
	readonly tick: number;
}

const connected = new Set<RBXScriptConnection>();

export function createScheduler({ name, onRender, onTick, phase, tick }: SchedulerOptions) {
	let timer = phase ?? 0;

	const connection = RunService.Heartbeat.Connect((deltaTime) => {
		const frameTime = math.min(deltaTime, tick);

		timer += frameTime;

		while (timer >= tick) {
			timer -= tick;
			debug.profilebegin(name);
			onTick?.(tick);
			debug.profileend();
		}

		onRender?.(frameTime, timer / tick);
	});

	connected.add(connection);

	return () => {
		connection.Disconnect();
		connected.delete(connection);
	};
}

export function disconnectAllSchedulers() {
	for (const connection of connected) {
		connection.Disconnect();
	}

	connected.clear();
}
