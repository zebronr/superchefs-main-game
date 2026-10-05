--!strict

local Item = require(script.Parent.Parent.Classes.Item)

-- Types shared by SkillService and the skill modules. Adding a skill: write a module in this folder
-- that returns a Skill, register it in SkillService, and map a character to it in Config.Skills.ByCharacter.

export type State = "Aiming" | "Active"

-- What SkillService gives a skill for one use. A skill must end every use with `Finish` (or be cancelled).
export type Context = {
	Player: Player,
	Character: Model,
	-- Moves to "Active" or back; SkillService already sets "Aiming" when Aim succeeds.
	SetState: (state: State) -> (),
	-- Ends the use: clears the state and starts the cooldown (seconds).
	Finish: (cooldown: number) -> (),
	-- False once the use was ended or cancelled (death, leaving, an interrupt).
	IsCurrent: () -> boolean,
}

export type Skill = {
	-- Seconds after Aim before the server cancels a missing Release.
	HoldTimeout: number,
	-- Called after SkillService validated the request (alive, ready, empty hands, not using). Return false to refuse.
	Aim: (ctx: Context) -> boolean,
	-- The player let go (direction is the client's aim) or the hold timed out (direction nil cancels).
	-- Target is an optional hint from the client and must never be trusted without validation.
	Release: (ctx: Context, direction: Vector3?, target: Instance?) -> (),
	-- A thrown item hit the player while aiming. The use ends without a cooldown.
	Interrupt: (ctx: Context) -> (),
	-- Drop everything: the player died, left or got a new character.
	Cancel: (ctx: Context) -> (),
	-- Optional: a player whose skill reaches a thrown item's step from `from` to `to`.
	FindIntercept: ((from: Vector3, to: Vector3) -> Player?)?,
	-- Optional: the thrown item that `FindIntercept` found, left anchored at `position`.
	TakeThrown: ((ctx: Context, item: Item.Item, position: Vector3) -> ())?,
}

return {}
