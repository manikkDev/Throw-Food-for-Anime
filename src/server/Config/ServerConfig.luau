--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/game.json `server_config`
-- Regenerate: python tools/gen_server_config.py
-- Server-only tunables: this module is under ServerScriptService and is never
-- sent to a client. Promo codes live here so they cannot be read before they
-- are announced.

local ServerConfig = {
	Codes = {
		WELCOME = {
			LuckyThrows = 3,
		},
		RELEASE = {
			YenMinutes = 20,
		},
	},
}

return ServerConfig
