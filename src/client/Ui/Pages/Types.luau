--!strict
-- Types - what a page module is, and what MenuController hands it.
--
-- A page turns the state it is given into what its screen shows, and turns a
-- press into a request. It never changes state and never decides a rule: it
-- fires the remote and waits for the next snapshot.

export type Ctx = {
	--- The last state snapshot, or nil before the first one.
	state: () -> any,
	--- Fire a client -> server remote by its Net name.
	fire: (name: string, ...any) -> (),
	--- Start a Robux purchase (a pass or a developer product row from Config).
	prompt: (item: any, isPass: boolean) -> (),
	--- The luck multiplier the player would throw with right now.
	luck: () -> number,
	--- Unix time now, advanced from the last snapshot.
	now: () -> number,
	--- Seconds played this session, advanced from the last snapshot.
	session: () -> number,
	--- A local notice.
	toast: (text: string, kind: string?) -> (),
	--- One big line on the HUD that fades by itself ("RANK UP!").
	banner: (text: string) -> (),
	--- The celebratory LEVEL UP banner (HudController:LevelUp): a rank up, new gear.
	levelUp: (title: string, sub: string, color: Color3?) -> (),
	--- The unboxing reward popup (HudController:Reward): { title, name, sub?,
	--- model?, image?, color?, rarity? }.
	reward: (info: any) -> (),
	--- Run `handler(yen, power)` on every server tick (once a second, and on
	--- every training rep).
	ticked: (handler: (yen: number, power: number) -> ()) -> (),
}

export type Page = {
	--- The ScreenGui this module drives.
	name: string,
	--- True for a HUD overlay (rendered on every snapshot, never "opened").
	overlay: boolean?,
	--- Find the instances and connect the buttons. Called once.
	init: (ctx: Ctx) -> (),
	--- Show `state`. Called on every snapshot while the page is open.
	render: (state: any) -> (),
	--- Once a second while the page is open (timers, what Yen can now buy).
	tick: ((state: any) -> ())?,
	opened: (() -> ())?,
	closed: (() -> ())?,
}

return {}
