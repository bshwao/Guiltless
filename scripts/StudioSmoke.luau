-- Run in Studio's command-bar context with the documented RunScript CLI task.
-- Test-only scripts are injected into the in-memory place, never the Rojo tree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")

assert(ReplicatedStorage.Remotes.Handshake:IsA("RemoteEvent"), "Missing Rojo Handshake")
assert(ServerScriptService.Server.Bootstrap:IsA("Script"), "Missing server bootstrap")
assert(
	StarterPlayer.StarterPlayerScripts.Client.Bootstrap:IsA("LocalScript"),
	"Missing client bootstrap"
)

local ack = Instance.new("RemoteEvent")
ack.Name = "Phase0SmokeAck"
ack.Parent = ReplicatedStorage

local server = Instance.new("Script")
server.Name = "Phase0SmokeServer"
server.Source = [=[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local remote = ReplicatedStorage.Remotes.Handshake
local lastNonce = {}
local completed = false
remote.OnServerEvent:Connect(function(player, payload)
	if type(payload) == "table" and type(payload.nonce) == "string" then
		lastNonce[player] = payload.nonce
	end
end)
ReplicatedStorage.Phase0SmokeAck.OnServerEvent:Connect(function(player, payload)
	if completed or type(payload) ~= "table" then
		return
	end
	if payload.nonce ~= lastNonce[player] or payload.clientConnected ~= true then
		return
	end
	completed = true
	StudioTestService:EndTest({ok = true, nonce = payload.nonce, client = player.Name})
end)
task.delay(35, function()
	if not completed then
		completed = true
		StudioTestService:EndTest({ok = false, reason = "Client did not confirm a validated reply and Connected HUD"})
	end
end)
]=]
server.Parent = ServerScriptService

local client = Instance.new("LocalScript")
client.Name = "Phase0SmokeClient"
client.Source = [=[
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Handshake")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.defs.Network)
local Validation = require(Shared.utils.NetworkValidation)
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local screen = gui:WaitForChild("ConnectionStatus", 20)
assert(screen, "Production client did not create its HUD")
local heading = screen.Panel.Status
local expectedHeading = "Guiltless " .. utf8.char(183) .. " Connected"
local deadline = os.clock() + 15
repeat task.wait(0.1) until heading.Text == expectedHeading or os.clock() >= deadline
assert(heading.Text == expectedHeading, "Production controller did not connect: " .. heading.Text)
assert(screen.Panel.Message.Text == Network.Greeting, "Production HUD did not show the server greeting")

-- Send a separate nonce after the production handshake's cooldown.
task.wait(Network.RequestIntervalSeconds + 0.2)
local nonce = HttpService:GenerateGUID(false)
local connection
connection = remote.OnClientEvent:Connect(function(payload)
	local reply = Validation.reply(payload)
	if reply and reply.nonce == nonce then
		connection:Disconnect()
		ReplicatedStorage.Phase0SmokeAck:FireServer({nonce = nonce, clientConnected = true})
	end
end)
remote:FireServer({version = Network.ProtocolVersion, nonce = nonce})
]=]
client.Parent = StarterPlayer.StarterPlayerScripts

-- Allow the newly loaded editor to settle before requesting a test session.
task.wait(3)
local result = StudioTestService:ExecuteMultiplayerTestAsync(1, { name = "GuiltlessPhase0" })
assert(
	type(result) == "table" and result.ok == true,
	"Studio round trip failed: " .. tostring(result)
)
print("GUILTLESS_PHASE0_PASS " .. HttpService:JSONEncode(result))
