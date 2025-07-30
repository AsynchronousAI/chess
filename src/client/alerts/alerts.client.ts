import { sendAlert } from "./alert-factory";
import { palette } from "shared/constants/palette";

sendAlert({
	scope: "ranking",
	emoji: "🏆",
	color: palette.yellow,
	colorSecondary: palette.peach,
	message: "hi!",
});
