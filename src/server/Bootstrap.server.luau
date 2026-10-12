--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared.defs.Network)
local HandshakeService = require(script.Parent.services.HandshakeService)

local remotes = ReplicatedStorage:WaitForChild(Network.FolderName, 10)
assert(remotes, "Missing ReplicatedStorage.Remotes; sync the Rojo project first.")
local remote = remotes:WaitForChild(Network.HandshakeName, 10)
assert(
	remote and remote:IsA("RemoteEvent"),
	"Missing Remotes.Handshake RemoteEvent; sync the Rojo project first."
)

local stop = HandshakeService.start(remote)
script.Destroying:Connect(stop)
print("[Handshake] Server ready.")
