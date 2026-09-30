-- [🌀 Портал Рика | t.me/Rickscript]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local p = Players.LocalPlayer
local m = p:GetMouse()

local GUN_NAME = "Rick Portal Gun"
local ASSET_ID = "rbxassetid://94472637589300"
local PORTAL_ASSET_ID = "rbxassetid://97461745338366"

local RANGE = 10000
local PORTAL_SCALE = 1.0
local PORTAL_GAP = 0.35
local COOLDOWN = 0.6

-- Настройки от вашата снимка
local cfgX = -0.05
local cfgY = -0.42
local cfgZ = 0.55
local cfgRotX = 40.00
local cfgRotY = 185.00
local cfgRotZ = 5.00
local cfgGunScale = 1.10

-- Звуки
local SHOT_SOUND_ID = "rbxassetid://74562584385247"
local PORTAL_SOUND_ID = "rbxassetid://102568033872947"
local CLOSE_SOUND_ID = "rbxassetid://79092478163364"

local tool, handle, muzzle
local portal1, portal2
local lastTeleport = 0
local arrivedAt = nil
local isTeleporting = false

-- Звук только для телепортации при входе в портал
local tSnd = Instance.new("Sound", workspace)
tSnd.SoundId = PORTAL_SOUND_ID
tSnd.Volume = 1.5

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 3,
		})
	end)
end

local function destroyPortalPart(portalObj, playSound)
	if not portalObj or not portalObj.part or not portalObj.part.Parent then return end
	
	-- Воспроизводим 3-й звук ТОЛЬКО если это автоматическое закрытие по таймеру (playSound == true)
	if playSound and portalObj.position then
		local soundPart = Instance.new("Part")
		soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
		soundPart.Transparency = 1
		soundPart.Anchored = true
		soundPart.CanCollide = false
		soundPart.Position = portalObj.position
		soundPart.Parent = workspace

		local closeSnd = Instance.new("Sound")
		closeSnd.SoundId = CLOSE_SOUND_ID
		closeSnd.Volume = 1.5
		closeSnd.Parent = soundPart
		closeSnd:Play()

		closeSnd.Ended:Connect(function()
			soundPart:Destroy()
		end)
		task.delay(5, function()
			if soundPart and soundPart.Parent then
				soundPart:Destroy()
			end
		end)
	end

	local portal = portalObj.part
	portalObj.part = nil

	local scaleVal = Instance.new("NumberValue")
	scaleVal.Value = PORTAL_SCALE

	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local scaleTween = TweenService:Create(scaleVal, tweenInfo, { Value = 0.001 })

	scaleVal.Changed:Connect(function(val)
		if portal and portal.Parent then
			pcall(function()
				portal:ScaleTo(val)
			end)
		end
	end)

	scaleTween:Play()
	scaleTween.Completed:Connect(function()
		scaleVal:Destroy()
		if portal and portal.Parent then
			portal:Destroy()
		end
	end)
end

local function cleanupToolOnly()
	local function checkAndDestroy(container)
		if not container then return end
		for _, v in ipairs(container:GetChildren()) do
			if v:IsA("Tool") and v.Name == GUN_NAME then
				v:Destroy()
			end
		end
	end

	checkAndDestroy(p:FindFirstChild("Backpack"))
	checkAndDestroy(p.Character)
end

local updateGun

local function buildGun()
	tool = Instance.new("Tool")
	tool.Name = GUN_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local success, objects = pcall(function()
		return game:GetObjects(ASSET_ID)
	end)

	if not success or not objects or not objects[1] then
		warn("Portal Gun model failed to load!")
		tool:Destroy()
		return nil
	end

	local source = objects[1]

	for _, obj in ipairs(source:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			obj:Destroy()
		end
	end

	local parts = {}
	for _, obj in ipairs(source:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
	end

	if #parts == 0 then
		source:Destroy()
		tool:Destroy()
		return nil
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, part in ipairs(parts) do
		local pos = part.Position
		minX = math.min(minX, pos.X)
		minY = math.min(minY, pos.Y)
		minZ = math.min(minZ, pos.Z)
		maxX = math.max(maxX, pos.X)
		maxY = math.max(maxY, pos.Y)
		maxZ = math.max(maxZ, pos.Z)
	end

	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	local modelRotation = CFrame.Angles(math.rad(cfgRotX), math.rad(cfgRotY), math.rad(cfgRotZ))

	for _, part in ipairs(parts) do
		local relative = CFrame.new(center):ToObjectSpace(part.CFrame)
		local scaledRelative = CFrame.new(relative.Position * cfgGunScale) * relative.Rotation
		part.CFrame = CFrame.new(center) * modelRotation * scaledRelative
		part.Size = part.Size * cfgGunScale

		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SpecialMesh") or child:IsA("FileMesh") or child:IsA("BlockMesh") or child:IsA("CylinderMesh") then
				child.Scale = child.Scale * cfgGunScale
			end
		end
	end

	handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true

	local gripOffset = CFrame.new(cfgX, cfgY, cfgZ)
	handle.CFrame = CFrame.new(center) * gripOffset
	handle.Parent = tool

	for _, part in ipairs(parts) do
		part.Parent = tool
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
	end

	source:Destroy()

	for _, part in ipairs(parts) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = handle
	end

	local minPartZ = math.huge
	for _, part in ipairs(parts) do
		local localPos = handle.CFrame:ToObjectSpace(part.CFrame).Position
		if localPos.Z < minPartZ then
			minPartZ = localPos.Z
		end
	end

	muzzle = Instance.new("Part", tool)
	muzzle.Name = "Muzzle"
	muzzle.Size = Vector3.new(0.2, 0.2, 0.2)
	muzzle.Transparency = 1
	muzzle.CanCollide = false
	muzzle.Massless = true
	muzzle.CFrame = handle.CFrame * CFrame.new(0, 0, minPartZ - 0.2)
	
	local muzzleWeld = Instance.new("WeldConstraint")
	muzzleWeld.Part0 = handle
	muzzleWeld.Part1 = muzzle
	muzzleWeld.Parent = handle

	tool.PrimaryPart = handle
	return tool
end

local function ignoreList()
	local list = {}
	if p.Character then table.insert(list, p.Character) end
	if tool then table.insert(list, tool) end
	if portal1 and portal1.part then table.insert(list, portal1.part) end
	if portal2 and portal2.part then table.insert(list, portal2.part) end
	return list
end

local function createBeam(startPos, endPos)
	local distance = (endPos - startPos).Magnitude
	if distance < 0.1 then return end

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Size = Vector3.new(0.2, 0.2, distance)
	beam.BrickColor = BrickColor.new("Lime green")
	beam.Material = Enum.Material.Neon
	beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = workspace

	local tween = TweenService:Create(
		beam,
		TweenInfo.new(0.15),
		{ Size = Vector3.new(0, 0, distance), Transparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		beam:Destroy()
	end)
end

local function createPortalPart(pos, norm)
	local targetCenter = pos + norm * PORTAL_GAP

	local up = Vector3.new(0, 1, 0)
	if math.abs(norm.Y) > 0.99 then
		up = Vector3.new(0, 0, 1)
	end

	local success, objects = pcall(function()
		return game:GetObjects(PORTAL_ASSET_ID)
	end)

	if not success or not objects or not objects[1] then
		warn("Portal Accessory failed to load!")
		return nil
	end

	local item = objects[1]
	local portal = Instance.new("Model")

	if item:IsA("Accessory") then
		for _, child in ipairs(item:GetChildren()) do
			child.Parent = portal
		end
		item:Destroy()
	elseif item:IsA("Model") then
		portal = item
	else
		item.Parent = portal
	end

	portal.Name = "RickPortal"
	portal.Parent = workspace

	for _, obj in ipairs(portal:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.CastShadow = false
		elseif obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			obj:Destroy()
		end
	end

	local baseCFrame = CFrame.lookAt(targetCenter, targetCenter + norm, up)
	portal:PivotTo(baseCFrame)

	local boxCf, _ = portal:GetBoundingBox()
	local offset = targetCenter - boxCf.Position
	baseCFrame = baseCFrame + offset
	portal:PivotTo(baseCFrame)

	local finalBoxCf, _ = portal:GetBoundingBox()
	local trueCenter = finalBoxCf.Position

	pcall(function()
		portal:ScaleTo(0.001)
	end)

	local scaleVal = Instance.new("NumberValue")
	scaleVal.Value = 0.001

	local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
	local scaleTween = TweenService:Create(scaleVal, tweenInfo, { Value = PORTAL_SCALE })

	scaleVal.Changed:Connect(function(val)
		if portal and portal.Parent then
			pcall(function()
				portal:ScaleTo(val)
			end)
		end
	end)

	scaleTween:Play()

	local rotation = 0
	local spinConn
	spinConn = RunService.RenderStepped:Connect(function(dt)
		if not portal or not portal.Parent then
			spinConn:Disconnect()
			scaleVal:Destroy()
			return
		end
		rotation = rotation + dt * 1.5
		portal:PivotTo(baseCFrame * CFrame.Angles(0, 0, rotation))
	end)

	scaleTween.Completed:Connect(function()
		scaleVal:Destroy()
	end)

	local portalObj = { part = portal, position = trueCenter, normal = norm }

	task.spawn(function()
		task.wait(15)
		if portal1 == portalObj then
			destroyPortalPart(portal1, true) -- Срабатывает звук по таймеру (15 сек)
			portal1 = nil
			arrivedAt = nil
		elseif portal2 == portalObj then
			destroyPortalPart(portal2, true) -- Срабатывает звук по таймеру (15 сек)
			portal2 = nil
			arrivedAt = nil
		end
	end)

	return portalObj
end

local function pointInside(portalObj, point)
	if not portalObj or not portalObj.part or not portalObj.part.Parent then return false end
	local cf = portalObj.part:GetPivot()
	local rel = cf:PointToObjectSpace(point)
	
	if rel.Z > 2.2 or rel.Z < -1.8 then return false end
	local radius = 3.5 * PORTAL_SCALE
	return (rel.X * rel.X + rel.Y * rel.Y) <= (radius * radius)
end

local function insidePortal(portal, root)
	if not portal or not portal.part or not portal.part.Parent then return false end
	local base = root.Position
	return pointInside(portal, base)
		or pointInside(portal, base - Vector3.new(0, 2.0, 0))
		or pointInside(portal, base + Vector3.new(0, 1.2, 0))
end

local function teleport(fromPortal, toPortal)
	local char = p.Character
	if not char or not toPortal or not toPortal.part or not toPortal.part.Parent then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local now = os.clock()
	if now - lastTeleport < COOLDOWN or arrivedAt == fromPortal or isTeleporting then return end

	isTeleporting = true
	lastTeleport = now

	if hum.SeatPart then hum.Sit = false end

	-- Вход в портал воспроизводит 2-й звук
	tSnd:Play()

	local enterPos = fromPortal.position
	local enterNorm = fromPortal.normal
	local exitPos = toPortal.position
	local exitNorm = toPortal.normal

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.Anchored = true

	local enterLook = Vector3.new(-enterNorm.X, 0, -enterNorm.Z)
	if enterLook.Magnitude < 0.01 then enterLook = hrp.CFrame.LookVector else enterLook = enterLook.Unit end

	local pullCF = CFrame.lookAt(enterPos - enterNorm * 0.8, enterPos - enterNorm * 0.8 + enterLook)
	local pullTween = TweenService:Create(
		hrp,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = pullCF }
	)
	pullTween:Play()
	pullTween.Completed:Wait()

	local launchVelocity
	local exitCF

	if exitNorm.Y > 0.7 then
		local exitLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if exitLook.Magnitude < 0.01 then exitLook = Vector3.new(0, 0, -1) else exitLook = exitLook.Unit end
		
		exitCF = CFrame.lookAt(exitPos + Vector3.new(0, 3.2, 0), exitPos + Vector3.new(0, 3.2, 0) + exitLook)
		launchVelocity = Vector3.new(0, 35, 0)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)

	elseif exitNorm.Y < -0.7 then
		local exitLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if exitLook.Magnitude < 0.01 then exitLook = Vector3.new(0, 0, -1) else exitLook = exitLook.Unit end

		exitCF = CFrame.lookAt(exitPos - Vector3.new(0, 3.5, 0), exitPos - Vector3.new(0, 3.5, 0) + exitLook)
		launchVelocity = (exitLook * 15) + Vector3.new(0, -20, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)

	else
		local wallDir = Vector3.new(exitNorm.X, 0, exitNorm.Z)
		if wallDir.Magnitude < 0.01 then wallDir = hrp.CFrame.LookVector else wallDir = wallDir.Unit end

		exitCF = CFrame.lookAt(exitPos + exitNorm * 3.0, exitPos + exitNorm * 3.0 + wallDir)
		
		launchVelocity = wallDir * 30
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	hrp.CFrame = exitCF
	hrp.Anchored = false

	hrp.AssemblyLinearVelocity = launchVelocity

	arrivedAt = toPortal
	isTeleporting = false

	task.spawn(function()
		task.wait(0.4)
		while arrivedAt == toPortal do
			local character = p.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not toPortal.part or not toPortal.part.Parent then
				arrivedAt = nil
				break
			end
			if not insidePortal(toPortal, root) then
				arrivedAt = nil
				break
			end
			task.wait(0.05)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	if not portal1 or not portal2 or isTeleporting then return end

	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if insidePortal(portal1, root) then
		teleport(portal1, portal2)
	elseif insidePortal(portal2, root) then
		teleport(portal2, portal1)
	end
end)

local function shoot()
	local camera = workspace.CurrentCamera
	if not camera or not muzzle then return end

	local ray = camera:ScreenPointToRay(m.X, m.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList()

	local result = workspace:Raycast(ray.Origin, ray.Direction * RANGE, params)

	-- Звук выстрела воспроизводится для каждого нового портала
	if not tSnd or not tSnd.IsPlaying then
		local shotSnd = Instance.new("Sound")
		shotSnd.SoundId = SHOT_SOUND_ID
		shotSnd.Volume = 1.2
		shotSnd.Parent = handle
		shotSnd:Play()
		shotSnd.Ended:Connect(function()
			shotSnd:Destroy()
		end)
	end

	if not result then
		createBeam(muzzle.Position, ray.Origin + ray.Direction * RANGE)
		return
	end

	createBeam(muzzle.Position, result.Position)

	if portal1 and portal2 then
		destroyPortalPart(portal1, false) -- Без звука закрытия при перестановке
		destroyPortalPart(portal2, false) -- Без звука закрытия при перестановке
		portal1, portal2 = nil, nil
		arrivedAt = nil
	end

	if not portal1 then
		portal1 = createPortalPart(result.Position, result.Normal)
	else
		portal2 = createPortalPart(result.Position, result.Normal)
	end
end

updateGun = function()
	local char = p.Character
	local wasEquipped = false
	if tool and char and tool.Parent == char then
		wasEquipped = true
	end

	cleanupToolOnly()
	local newGun = buildGun()
	if not newGun then return end

	newGun.Activated:Connect(shoot)

	local backpack = p:FindFirstChild("Backpack")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if wasEquipped and backpack and hum then
		newGun.Parent = backpack
		task.defer(function()
			if hum and hum.Health > 0 and newGun.Parent == backpack then
				hum:EquipTool(newGun)
			end
		end)
	else
		if backpack then
			newGun.Parent = backpack
		end
	end
end

updateGun()
notify("Rick scripts", "Портальная пушка загружена!")

p.CharacterAdded:Connect(function()
	task.wait(0.5)
	updateGun()
end)
