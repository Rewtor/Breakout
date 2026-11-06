-- Diagnostic loader for the unchanged teste4. Logs locally; does not change movement.
local source = game:HttpGet("https://raw.githubusercontent.com/Rewtor/Breakout/a26c6f8505179b54a17abafcf51dc4d2ef6b9a75/teste4.luau")
source = source:gsub("\r\n", "\n")
local needle = [[        local callback = definition.module.bind(sourceTables, selectedOptions, context)
        context.callbacks[factoryIndex] = callback]]
local replacement = [[        local callback = definition.module.bind(sourceTables, selectedOptions, context)
        if factoryIndex == 3 or factoryIndex == 7 or factoryIndex == 13 then
            local original = callback
            callback = function(...)
                local arguments = table.pack(...)
                local started = os.clock()
                local sharedState = sourceTables[15]
                local function snapshot()
                    local root = sharedState[15]()
                    local humanoid = sharedState[8]()
                    local cfg = sharedState[25] or {}
                    local target = arguments[1]
                    local character = sharedState[1].Character
                    local guardTables = sourceTables[34] and sourceTables[34][34]
                    return string.format("route=%d move=%s admin=%s invis=%s target=%s area=%s pos=%s distance=%s speed=%s localGuards=%s",
                        factoryIndex, tostring(cfg.moveTo), tostring(cfg.adminSteal),
                        tostring(character and character:GetAttribute("InvisApplied")),
                        tostring(type(target)=="table" and target.Uid), tostring(type(target)=="table" and target.a),
                        tostring(root and root.Position),
                        tostring(root and type(target)=="table" and target.Pos and (root.Position-target.Pos).Magnitude),
                        tostring(humanoid and humanoid.WalkSpeed), tostring(guardTables and #guardTables))
                end
                pcall(function() __diceTpTrace("BEGIN " .. snapshot()) end)
                local connection
                if factoryIndex == 7 then
                    local elapsed, samples = 0, 0
                    connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
                        elapsed = elapsed + dt
                        if elapsed < 0.25 then return end
                        elapsed = 0
                        samples = samples + 1
                        pcall(function() __diceTpTrace("SAMPLE " .. snapshot()) end)
                        if samples >= 24 and connection then connection:Disconnect(); connection = nil end
                    end)
                end
                local result = table.pack(pcall(original, table.unpack(arguments, 1, arguments.n)))
                if connection then connection:Disconnect() end
                pcall(function()
                    __diceTpTrace(string.format("END route=%d duration=%.3f ok=%s result=%s reason=%s | %s",
                        factoryIndex, os.clock()-started, tostring(result[1]), tostring(result[2]), tostring(result[3]), snapshot()))
                end)
                if not result[1] then error(result[2], 0) end
                return table.unpack(result, 2, result.n)
            end
        end
        context.callbacks[factoryIndex] = callback]]
local first, last = source:find(needle, 1, true)
assert(first and not source:find(needle, last + 1, true), "Unexpected teste4 revision; instrumentation stopped")
source = source:sub(1, first - 1) .. replacement .. source:sub(last + 1)
local logger = [[
local __diceTpLines = {}
local function __diceTpTrace(message)
    local line = string.format("[T4 Teleport %.3f] %s", os.clock(), message)
    print(line)
    __diceTpLines[#__diceTpLines+1] = line
    if #__diceTpLines > 300 then table.remove(__diceTpLines, 1) end
    if writefile then pcall(writefile, "DiceRadar_TeleportTrace.txt", table.concat(__diceTpLines, "\n")) end
end
__diceTpTrace("Diagnostic loaded: 3=standard approach, 7=Teleport route, 13=Instant Steal V3. Logging is local.")
]]
local chunk, failure = loadstring(logger .. "\n" .. source, "teste4-teleport-trace")
assert(chunk, failure)
return chunk()
