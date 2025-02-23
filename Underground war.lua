-- Script nâng cao với kiểm tra vật cản trước khi bắn

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage.Events.Remote.ShotTarget
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- Cấu hình ban đầu
local targetTeamName = "Red"  -- Đội mục tiêu ban đầu
local cooldown = 0  -- Thời gian chờ giữa các lần bắn (giây)
local bulletSpeed = 49.5  -- Tốc độ đạn (stud/giây)
local lastShotTime = 0  -- Thời gian bắn cuối cùng

-- Các thiết lập cho tính toán ping
local PingEvent = ReplicatedStorage.Events.Remote:FindFirstChild("Ping")
if not PingEvent then
    PingEvent = Instance.new("RemoteEvent")
    PingEvent.Name = "Ping"
    PingEvent.Parent = ReplicatedStorage.Events.Remote
end

local pingDelay = 0
local lastPingRequest = 0
local pingHistory = {}
local maxPingSamples = 5

-- Cấu hình dự đoán: sử dụng dự đoán clamping tùy chọn và bù trừ trọng lực
local useClampedPrediction = false  -- Đặt thành true nếu bạn muốn dùng clamping cho khoảng cách dự đoán
local minPredictionDistance = 0   -- Khoảng cách tối thiểu cho dự đoán (stud) nếu clamping
local maxPredictionDistance = 10  -- Khoảng cách tối đa cho dự đoán (stud) nếu clamping

local gravityCompensationEnabled = true  -- Bật bù trừ trọng lực cho đạn (nếu cần)
local gravity = 196.2  -- Giá trị trọng lực mặc định trong Roblox (stud/s^2)

------------------------------------------------
-- Hàm cập nhật ping với trung bình của các mẫu
PingEvent.OnClientEvent:Connect(function(response)
    if response == "pong" and lastPingRequest then
        local currentPing = tick() - lastPingRequest
        table.insert(pingHistory, currentPing)
        if #pingHistory > maxPingSamples then
            table.remove(pingHistory, 1)
        end
        local totalPing = 0
        for _, ping in ipairs(pingHistory) do
            totalPing = totalPing + ping
        end
        pingDelay = totalPing / #pingHistory
        print("Average Ping: " .. pingDelay)
    end
end)

local function updatePing()
    lastPingRequest = tick()
    PingEvent:FireServer("ping")
end

spawn(function()
    while true do
         updatePing()
         wait(5)
    end
end)

------------------------------------------------
-- Hàm animateNotification và displayNotification
local function animateNotification(notification)
    local endPos = UDim2.new(0.5, -100, 0.4, -50)
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0)
    local tween = game:GetService("TweenService"):Create(notification, tweenInfo, {Position = endPos})
    tween:Play()
    wait(2)
    tween:Destroy()
end

local function displayNotification(message)
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = notification
    textLabel.Size = UDim2.new(0, 200, 0, 50)
    textLabel.Position = UDim2.new(0.5, -100, 0.55, -50)
    textLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Text = message
    textLabel.TextSize = 20
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    notification.Parent = player:WaitForChild("PlayerGui")
    animateNotification(textLabel)
    wait(2)
    for transparency = 0, 1, 0.1 do
        textLabel.BackgroundTransparency = transparency
        wait(0.1)
    end
    notification:Destroy()
end

------------------------------------------------
-- Hàm playSound
local function playSound(soundId, delay)
    delay = delay or 0
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Parent = SoundService
    sound:Play()
    wait(delay)
    sound:Destroy()
end

spawn(function()
    playSound(2865227271, 0.5)
    wait(0.5)
    playSound(1676318332)
end)

------------------------------------------------
-- Hàm tìm kiếm người chơi gần nhất
local function findClosestPlayer()
    local players = game.Players:GetPlayers()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
    if tool then
        local toolHandle = tool:FindFirstChild("Handle")
        if toolHandle then
            local shooterPosition = toolHandle.Position
            for _, plyr in ipairs(players) do
                if plyr ~= player and plyr.Team and plyr.Team.Name == targetTeamName and plyr.Character and plyr.Character:FindFirstChild("Humanoid") and plyr.Character.Humanoid.Health > 0 then
                    local targetPosition = plyr.Character.HumanoidRootPart.Position
                    local horizontalDistance = (targetPosition - shooterPosition).magnitude
                    local heightDifference = math.abs(targetPosition.Y - shooterPosition.Y)
                    local totalDistance = (horizontalDistance^1 + heightDifference^2)^0.5
                    if totalDistance < shortestDistance then
                        closestPlayer = plyr
                        shortestDistance = totalDistance
                    end
                end
            end
        else
            print("Tool does not have a handle.")
        end
    else
        print("No tool equipped.")
    end
    return closestPlayer, shortestDistance
end

------------------------------------------------
-- Hàm dự đoán vị trí nâng cao với tính toán ping trung bình và bù trừ trọng lực
local function predictPosition(targetPosition, targetVelocity)
    local shooterPosition = player.Character.HumanoidRootPart.Position
    local distanceToTarget = (targetPosition - shooterPosition).magnitude

    local effectiveDistance = distanceToTarget
    if useClampedPrediction then
        effectiveDistance = math.clamp(distanceToTarget, minPredictionDistance, maxPredictionDistance)
    end

    local timeToImpact = effectiveDistance / bulletSpeed
    local adjustedTime = timeToImpact + pingDelay

    local predictedPos = targetPosition + targetVelocity * adjustedTime

    if gravityCompensationEnabled then
        predictedPos = predictedPos - Vector3.new(0, 0.5 * gravity * (adjustedTime^2), 0)
    end

    return predictedPos
end

------------------------------------------------
-- Hàm kiểm tra đường bắn có bị cản hay không
local function isClearShot(shooterPosition, predictedPosition, targetCharacter)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local filterList = {}
    if player.Character then
        table.insert(filterList, player.Character)
    end
    if targetCharacter then
        table.insert(filterList, targetCharacter)
    end
    rayParams.FilterDescendantsInstances = filterList

    local direction = predictedPosition - shooterPosition
    local rayResult = Workspace:Raycast(shooterPosition, direction, rayParams)
    if rayResult then
        print("Obstacle detected: " .. rayResult.Instance:GetFullName())
    end
    return rayResult == nil
end

------------------------------------------------
-- Hàm bắn RemoteEvent (với kiểm tra vật cản)
local function fireRemoteEvent(targetPlayer)
    if targetPlayer then
        local currentTime = os.time()
        if currentTime - lastShotTime >= cooldown then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity
            local predictedPosition = predictPosition(targetPosition, targetVelocity)
            
            local shooterPosition = player.Character.HumanoidRootPart.Position
            if not isClearShot(shooterPosition, predictedPosition, targetPlayer.Character) then
                print("Đường bắn bị cản, không thực hiện bắn.")
                return
            end

            local args = {[1] = predictedPosition, [2] = "Sniper"}
            RemoteEvent:FireServer(unpack(args))
            local tool = player.Character:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
            end
            lastShotTime = currentTime
        end
    else
        print("Không tìm thấy đối tượng hợp lệ.")
    end
end

------------------------------------------------
-- Hàm chuyển đổi đội mục tiêu
local function toggleTargetTeam()
    targetTeamName = (targetTeamName == "Red") and "Blue" or "Red"
    displayNotification("Now targeting " .. targetTeamName .. " team.")
end

------------------------------------------------
-- Tạo giao diện người dùng
local gui = Instance.new("ScreenGui")
gui.Parent = game:GetService("CoreGui")

local teamToggleButton = Instance.new("TextButton")
teamToggleButton.Parent = gui
teamToggleButton.Position = UDim2.new(0.7, 0, 0.1, 0)
teamToggleButton.Size = UDim2.new(0, 200, 0, 50)
teamToggleButton.Text = "Toggle Target Team"
teamToggleButton.MouseButton1Click:Connect(toggleTargetTeam)

local targetButton = Instance.new("TextButton")
targetButton.Parent = gui
targetButton.Position = UDim2.new(0.7, 0, 0.25, 0)
targetButton.Size = UDim2.new(0, 200, 0, 50)
targetButton.Text = "Target Closest Player"
targetButton.MouseButton1Click:Connect(function()
    fireRemoteEvent(findClosestPlayer())
end)
