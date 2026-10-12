--!strict

export type HandshakeRequest = {
	version: number,
	nonce: string,
}

export type HandshakeReply = {
	version: number,
	nonce: string,
	message: string,
}

return {}
