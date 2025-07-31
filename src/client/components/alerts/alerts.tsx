import React from "@rbxts/react";

import { Alert } from "./alert";
import Atoms from "shared/atoms";
import { useAtom } from "@rbxts/react-charm";

export function Alerts() {
	const alerts = useAtom(Atoms.Alerts);

	return (
		<>
			{alerts.map((alert, index) => (
				<Alert key={alert.id} alert={alert} index={index} />
			))}
		</>
	);
}
