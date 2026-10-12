--!strict

local Network = require(script.Parent.Parent.defs.Network)
local NetworkTypes = require(script.Parent.Parent.types.NetworkTypes)

local NetworkValidation = {}

function NetworkValidation.request(payload: unknown): NetworkTypes.HandshakeRequest?
	if typeof(payload) ~= "table" then
		return nil
	end

	local fields = payload :: { [string]: unknown }
	local version = fields.version
	local nonce = fields.nonce
	if version ~= Network.ProtocolVersion or typeof(nonce) ~= "string" then
		return nil
	end
	if #nonce == 0 or #nonce > Network.MaximumNonceLength then
		return nil
	end

	return { version = Network.ProtocolVersion, nonce = nonce }
end

function NetworkValidation.reply(payload: unknown): NetworkTypes.HandshakeReply?
	local request = NetworkValidation.request(payload)
	if request == nil then
		return nil
	end

	local fields = payload :: { [string]: unknown }
	if fields.message ~= Network.Greeting then
		return nil
	end

	return {
		version = request.version,
		nonce = request.nonce,
		message = Network.Greeting,
	}
end

return table.freeze(NetworkValidation)
