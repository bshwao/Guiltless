--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.defs.Network)
local HandshakeController = require(script.Parent.controllers.HandshakeController)
local ConnectionStatus = require(script.Parent.UI.ConnectionStatus)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
assert(playerGui:IsA("PlayerGui"), "Expected LocalPlayer.PlayerGui.")
local status = ConnectionStatus.create(playerGui)

local remotes = ReplicatedStorage:WaitForChild(Network.FolderName, 10)
if remotes == nil then
	status.set("TimedOut", "Remote folder missing. Sync the Rojo project, then restart Play.")
	error("Missing ReplicatedStorage.Remotes.")
end
local remote = remotes:WaitForChild(Network.HandshakeName, 10)
if remote == nil or not remote:IsA("RemoteEvent") then
	status.set("TimedOut", "Handshake remote missing. Sync Rojo, then restart Play.")
	error("Missing Remotes.Handshake RemoteEvent.")
end

local stop = HandshakeController.start(remote, status)
script.Destroying:Connect(function()
	stop()
	status.destroy()
end)
