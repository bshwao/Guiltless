--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.defs.Network)
local NetworkValidation = require(Shared.utils.NetworkValidation)

local HandshakeService = {}

function HandshakeService.start(remote: RemoteEvent): () -> ()
	local lastRequestAt: { [Player]: number } = {}

	local requestConnection = remote.OnServerEvent:Connect(
		function(player: Player, payload: unknown)
			local request = NetworkValidation.request(payload)
			if request == nil then
				return
			end

			local now = os.clock()
			local previous = lastRequestAt[player]
			if previous ~= nil and now - previous < Network.RequestIntervalSeconds then
				return
			end
			lastRequestAt[player] = now

			remote:FireClient(player, {
				version = Network.ProtocolVersion,
				nonce = request.nonce,
				message = Network.Greeting,
			})
			print(("[Handshake] Replied to %s."):format(player.Name))
		end
	)

	local removingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		lastRequestAt[player] = nil
	end)

	return function()
		requestConnection:Disconnect()
		removingConnection:Disconnect()
		table.clear(lastRequestAt)
	end
end

return HandshakeService
