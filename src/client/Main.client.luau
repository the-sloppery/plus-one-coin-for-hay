--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local View = require(script.Parent.View)
local player = Players.LocalPlayer
local action = ReplicatedStorage:WaitForChild("HayAction", 15)
local updates = ReplicatedStorage:WaitForChild("HayState", 15)
assert(action and action:IsA("RemoteEvent"), "HayAction did not replicate")
assert(updates and updates:IsA("RemoteEvent"), "HayState did not replicate")
local function send(verb: string, value: any?)
	action:FireServer(verb, value)
end
local controller = View.create(player:WaitForChild("PlayerGui"), player.UserId, send)
local snapshot: any = nil
updates.OnClientEvent:Connect(function(data)
	if data.kind == "message" then
		controller.notify(data.text)
	else
		snapshot = data
		controller.render(data)
	end
end)
local loading = Instance.new("ScreenGui")
loading.Name = "HayTravel"
local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(42, 91, 75)
background.Parent = loading
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(0.8, 0.3)
label.Position = UDim2.fromScale(0.1, 0.35)
label.BackgroundTransparency = 1
label.Text = "Off to the haystack…\nBring sharp eyes."
label.TextColor3 = Color3.fromRGB(255, 246, 219)
label.TextSize = 30
label.TextWrapped = true
label.Font = Enum.Font.GothamBold
label.Parent = background
TeleportService:SetTeleportGui(loading)
local function clearNearest(_, inputState: Enum.UserInputState)
	if
		inputState ~= Enum.UserInputState.Begin
		or not snapshot
		or snapshot.mode ~= "field"
		or controller.gui:GetAttribute("JournalOpen")
	then
		return Enum.ContextActionResult.Pass
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return Enum.ContextActionResult.Pass
	end
	-- Streaming-safe: only choose a hay cell physically near this avatar, never request a reward.
	local nearest: BasePart? = nil
	local distance = 14
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and string.sub(model.Name, 1, 8) == "HayField" then
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and p:GetAttribute("CellIndex") and p.Transparency < 1 then
					local d = (p.Position - root.Position).Magnitude
					if d < distance then
						nearest = p
						distance = d
					end
				end
			end
		end
	end
	if nearest then
		send("dig", nearest:GetAttribute("CellIndex"))
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction(
	"ClearHay",
	clearNearest,
	true,
	Enum.KeyCode.F,
	Enum.KeyCode.ButtonR2
)
ContextActionService:SetTitle("ClearHay", "Clear hay")
ContextActionService:SetPosition("ClearHay", UDim2.fromScale(0.7, 0.55))
UserInputService.InputBegan:Connect(function(input, processed)
	if
		not processed and (input.KeyCode == Enum.KeyCode.J or input.KeyCode == Enum.KeyCode.ButtonY)
	then
		controller.panel("contracts")
	elseif input.KeyCode == Enum.KeyCode.ButtonB and controller.gui:GetAttribute("JournalOpen") then
		controller.panel(nil)
	end
end)
send("sync", nil)
