import { peek } from "@rbxts/charm";
import { throttle } from "@rbxts/set-timeout";
import Atoms, { Alert, AlertScope } from "shared/atoms";
import { palette } from "shared/constants/palette";

const defaultAlert: Alert = {
	id: 0,
	emoji: "✅",
	message: "Alert",
	color: palette.green,
	duration: 5,
	visible: true,
};

let nextAlertId = 0;

const scopedThrottles: Record<AlertScope, (callback: () => number) => number> = {
	money: throttle((callback) => callback(), 0.8),
	ranking: throttle((callback) => callback(), 0.8),
};

function sendAlertImmediate(patch: Partial<Alert>) {
	const alert: Alert = {
		...defaultAlert,
		...patch,
		id: nextAlertId++,
	};

	if (alert.scope) {
		dismissAlertsOfScope(alert.scope);
	}

	Atoms.Alerts((current) => [...current, alert]);

	Promise.delay(alert.duration).then(() => {
		dismissAlert(alert.id);
	});

	return alert.id;
}

export function sendAlert(patch: Partial<Alert>) {
	if (!patch.scope) {
		return sendAlertImmediate(patch);
	}

	return scopedThrottles[patch.scope](() => {
		return sendAlertImmediate(patch);
	});
}

export async function dismissAlert(id: number) {
	const visible = false;
	Atoms.Alerts((current) => current.map((alert) => (alert.id === id ? { ...alert, visible } : alert)));

	return Promise.delay(0.25).then(() => {
		/* filter it out */
		Atoms.Alerts((current) => current.filter((alert) => alert.id !== id));
		return id;
	});
}

function dismissAlertsOfScope(scope: string) {
	for (const alert of peek(Atoms.Alerts)) {
		if (alert.scope === scope) {
			dismissAlert(alert.id);
		}
	}
}
