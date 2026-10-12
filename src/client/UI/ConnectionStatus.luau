--!strict

export type State = "Connecting" | "Connected" | "TimedOut"

export type View = {
	set: (state: State, message: string) -> (),
	setRetryEnabled: (enabled: boolean) -> (),
	onRetry: (callback: () -> ()) -> RBXScriptConnection,
	destroy: () -> (),
}

local COLORS: { [State]: Color3 } = {
	Connecting = Color3.fromRGB(255, 204, 102),
	Connected = Color3.fromRGB(131, 224, 172),
	TimedOut = Color3.fromRGB(255, 148, 148),
}

local ConnectionStatus = {}

function ConnectionStatus.create(playerGui: PlayerGui): View
	local screen = Instance.new("ScreenGui")
	screen.Name = "ConnectionStatus"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Position = UDim2.fromOffset(16, 16)
	frame.Size = UDim2.fromOffset(330, 126)
	frame.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local heading = Instance.new("TextLabel")
	heading.Name = "Status"
	heading.Position = UDim2.fromOffset(14, 10)
	heading.Size = UDim2.new(1, -28, 0, 25)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 16
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Name = "Message"
	detail.Position = UDim2.fromOffset(14, 39)
	detail.Size = UDim2.new(1, -28, 0, 36)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 13
	detail.TextColor3 = Color3.fromRGB(223, 227, 235)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.TextWrapped = true
	detail.Parent = frame

	local retry = Instance.new("TextButton")
	retry.Name = "Retry"
	retry.Position = UDim2.fromOffset(14, 85)
	retry.Size = UDim2.fromOffset(125, 27)
	retry.BackgroundColor3 = Color3.fromRGB(61, 68, 84)
	retry.BorderSizePixel = 0
	retry.Font = Enum.Font.Gotham
	retry.TextSize = 13
	retry.TextColor3 = Color3.fromRGB(244, 246, 250)
	retry.Text = "Retry (R)"
	retry.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 5)
	buttonCorner.Parent = retry

	screen.Parent = playerGui

	local view: View = {
		set = function(state: State, message: string)
			heading.Text = "Guiltless · " .. state
			heading.TextColor3 = COLORS[state]
			detail.Text = message
		end,
		setRetryEnabled = function(enabled: boolean)
			retry.Active = enabled
			retry.AutoButtonColor = enabled
			retry.TextTransparency = if enabled then 0 else 0.5
		end,
		onRetry = function(callback: () -> ()): RBXScriptConnection
			return retry.MouseButton1Click:Connect(callback)
		end,
		destroy = function()
			screen:Destroy()
		end,
	}

	view.set("Connecting", "Contacting the server…")
	view.setRetryEnabled(false)
	return view
end

return ConnectionStatus
