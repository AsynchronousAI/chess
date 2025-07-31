import { images } from "shared/assets";

export interface SnakeSkin {
	readonly boostTint?: ReadonlyArray<Color3>;
	readonly eyeTextureLeft: string;
	readonly eyeTextureRight: string;
	readonly headColor?: Color3;
	readonly headTexture?: string;
	readonly id: string;
	readonly price: number;
	readonly primary?: Color3;
	readonly secondary?: Color3;
	readonly size: Vector2;
	readonly texture: ReadonlyArray<string>;
	readonly tint: ReadonlyArray<Color3>;
}

export const defaultSnakeSkin: SnakeSkin = {
	eyeTextureLeft: images.skins.snake_eye_left,
	eyeTextureRight: images.skins.snake_eye_right,
	id: "default",
	price: 0,
	size: new Vector2(512, 512),
	texture: [images.skins.snake_main],
	tint: [Color3.fromRGB(255, 255, 255)],
};
