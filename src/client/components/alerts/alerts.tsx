import React from "@rbxts/react";
import { useAtom } from "@rbxts/react-charm";

import Atoms from "shared/atoms";

import { Alert } from "./alert";

export function Alerts() {
	const alerts = useAtom(Atoms.Alerts);

	return (
		<>
			{alerts.map((alert, index) => {
				return <Alert key={alert.id} alert={alert} index={index} />;
			})}
		</>
	);
}
