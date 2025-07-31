import { palette } from "shared/constants/palette";

import { sendAlert } from "./alert-factory";

sendAlert({
	color: palette.yellow,
	colorSecondary: palette.peach,
	emoji: "🏆",
	message: "hi!",
	scope: "ranking",
});
