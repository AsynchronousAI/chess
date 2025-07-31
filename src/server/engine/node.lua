-- ROBLOX upstream: node.ts
local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
local LuauPolyfill = TS.import(script, game:GetService("ReplicatedStorage"), "rbxts_include", "node_modules", "@rbxts", "luau-polyfill", "out")
type Array<T> = LuauPolyfill.Array<T>
local exports = {}
export type Node = {
	move: string?,
	suffixAnnotation: string?,
	nags: Array<string>,
	comment: string?,
	variations: Array<Node>,
}
return exports
