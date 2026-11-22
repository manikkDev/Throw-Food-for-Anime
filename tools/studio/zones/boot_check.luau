local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local problems = {}
for _, e in LogService:GetLogHistory() do
	if e.messageType == Enum.MessageType.MessageError or e.messageType == Enum.MessageType.MessageWarning then
		local m = e.message
		if not (m:find("203785492") or m:find("being generated") or m:find("Assistant plugin")) then
			table.insert(problems, m:sub(1, 160))
		end
	end
end
local p = Players:GetPlayers()[1]
return string.format("players %d, character %s, problems %d\n%s", #Players:GetPlayers(), tostring(p ~= nil and p.Character ~= nil), #problems, table.concat(problems, "\n"))
