--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.defs.Network)
local NetworkValidation = require(Shared.utils.NetworkValidation)
local ConnectionStatus = require(script.Parent.Parent.UI.ConnectionStatus)

local HandshakeController = {}

function HandshakeController.start(remote: RemoteEvent, status: ConnectionStatus.View): () -> ()
	local running = true
	local pendingNonce: string? = nil
	local lastSentAt = -math.huge

	local function refreshRetry()
		status.setRetryEnabled(
			pendingNonce == nil and os.clock() - lastSentAt >= Network.RequestIntervalSeconds
		)
	end

	local function request()
		if
			not running
			or pendingNonce ~= nil
			or os.clock() - lastSentAt < Network.RequestIntervalSeconds
		then
			return
		end

		local nonce = HttpService:GenerateGUID(false)
		pendingNonce = nonce
		lastSentAt = os.clock()
		status.set("Connecting", "Contacting the server…")
		status.setRetryEnabled(false)
		remote:FireServer({ version = Network.ProtocolVersion, nonce = nonce })

		task.delay(Network.RequestIntervalSeconds, function()
			if running then
				refreshRetry()
			end
		end)
		task.delay(Network.TimeoutSeconds, function()
			if not running or pendingNonce ~= nonce then
				return
			end
			pendingNonce = nil
			status.set("TimedOut", "No server reply. Check Studio Output, then retry.")
			refreshRetry()
			warn("[Handshake] No matching reply within " .. Network.TimeoutSeconds .. " seconds.")
		end)
	end

	-- Listen first so even an immediate reply cannot race the initial request.
	local replyConnection = remote.OnClientEvent:Connect(function(payload: unknown)
		local reply = NetworkValidation.reply(payload)
		if not running or reply == nil or pendingNonce == nil or reply.nonce ~= pendingNonce then
			return
		end
		pendingNonce = nil
		status.set("Connected", reply.message)
		refreshRetry()
		print("[Handshake] " .. reply.message)
	end)

	local retryConnection = status.onRetry(request)
	local inputConnection = UserInputService.InputBegan:Connect(
		function(input: InputObject, gameProcessed: boolean)
			if
				not gameProcessed
				and UserInputService:GetFocusedTextBox() == nil
				and input.KeyCode == Enum.KeyCode.R
			then
				request()
			end
		end
	)

	request()

	return function()
		running = false
		pendingNonce = nil
		replyConnection:Disconnect()
		retryConnection:Disconnect()
		inputConnection:Disconnect()
	end
end

return HandshakeController
