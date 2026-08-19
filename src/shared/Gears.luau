-- UTILS / HELPER FUNCTIONS

local RunService = game:GetService("RunService")

local Gears = {}

-- #region DATA

function Gears.DeepCopy(original)
	local copy = {}

	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = Gears.DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

-- #endregion

-- #region BITWISE OPERATIONS

function Gears.GetMask(system_id)
	return bit32.lshift(1, system_id)
end

function Gears.AddMask(entityMask, systemMask)
	return bit32.bor(entityMask, systemMask)
end

function Gears.RemoveMask(entityMask, systemMask)
	local inverseMask = bit32.bnot(systemMask)
	return bit32.band(entityMask, inverseMask)
end

-- #endregion

-- #region TABLES

--- CHeck if a Table is empty
function Gears.IsEmpty(t)
	local next = next(t)

	return next == nil
end

function Gears.UniqueInsert(t, element)
	if not table.find(t, element) then
		table.insert(t, element)
	end
end

--- Set LastElement at Index -> table[index] = lastElement
function Gears.ReplaceWithLastElement(t, index)
	local lastElement = table.remove(t, #t)
	t[index] = lastElement

	return lastElement
end

-- Index1 = First Element
function Gears.SwapTableElements(t, index1, index2)
	local element1 = table.remove(t, index1)
	local element2 = table.remove(t, index2 - 1)

	table.insert(t, index1, element2)
	table.insert(t, index2, element1)

	return element1, element2
end

function Gears.JoinTable(table1, table2)
	for _, element in pairs(table2) do
		table.insert(table1, element)
	end
end

function Gears.FuseTable(table1, table2)
	for key, element in pairs(table2) do
		table1[key] = element
	end
end

function Gears.SplitTable(table1, table2)
	for _, element in ipairs(table2) do
		local index = table.find(table1, element)

		if index then
			table.remove(table1, index)
		end
	end
end

function Gears.FindWhere(table, condition)
	for _, item in pairs(table) do
		if condition(item) then
			return item
		end
	end

	return nil
end

function Gears.TableSize(t)
	local count = 0

	for _ in pairs(t) do
		count = count + 1
	end

	return count
end

function Gears.SumTable(t)
	local total = 0

	for i = 1, #t do
		total += t[i]
	end

	return total
end

-- #endregion

-- #region INSTANCES & CHARACTERS

function Gears.GetPartCount(parentObject)
	local count = 0

	for _, object in ipairs(parentObject:GetDescendants()) do
		if object:IsA("BasePart") then
			count += 1
		end
	end

	return count
end

function Gears.FindHumanoidFromPart(part)
	local character = part.Parent

	if character then
		return character:FindFirstChild("Humanoid")
	end

	return nil
end

--- Take a table Of Parts
---@return table uniqueHumanoids
function Gears.FindUniqueHumanoids(parts, charactersBanned)
	local humanoids = {}

	for _, hit in pairs(parts) do
		local humanoid = Gears.FindHumanoidFromPart(hit)

		local isInBanList = charactersBanned and table.find(charactersBanned, humanoid.Parent)
		local isValid = humanoid and not table.find(humanoids, humanoid) and not isInBanList

		if not isValid then
			continue
		end

		table.insert(humanoids, humanoid)
	end

	return humanoids
end

--- Anchor Every Part in a Model
function Gears.AnchorModel(character, isAnchored)
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Part") then
			child.Anchored = isAnchored
		end
	end
end

--- Get the Body Parts of a R6 Model
function Gears.GetBodyParts(character)
	local torso = character.Torso or character.UpperTorso
	local head = character.Head
	local leftArm = character:FindFirstChild("Left Arm")
	local leftLeg = character:FindFirstChild("Left Leg")
	local rightArm = character:FindFirstChild("Right Arm")
	local rightLeg = character:FindFirstChild("Right Leg")

	assert(torso, character.Name .. " Missing Body Part")
	assert(head, character.Name .. " Missing Body Part")
	assert(leftArm, character.Name .. " Missing Body Part")
	assert(leftLeg, character.Name .. " Missing Body Part")
	assert(rightArm, character.Name .. " Missing Body Part")
	assert(rightLeg, character.Name .. " Missing Body Part")

	return torso, head, leftArm, leftLeg, rightArm, rightLeg
end

--- Get the Limbs Joints of a R6 Model
function Gears.GetJoints(character)
	local torso = character.Torso

	assert(torso, character.Name .. " Missing Torso")

	local rootJoint
	local neck = torso:FindFirstChild("Neck") :: Motor6D
	local leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D
	local leftHip = torso:FindFirstChild("Left Hip") :: Motor6D
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D
	local rightHip = torso:FindFirstChild("Right Hip") :: Motor6D

	assert(neck, character.Name .. " Missing Joint")
	assert(leftShoulder, character.Name .. " Missing Joint")
	assert(leftHip, character.Name .. " Missing Joint")
	assert(rightShoulder, character.Name .. " Missing Joint")
	assert(rightHip, character.Name .. " Missing Joint")

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoidRootPart then
		rootJoint = humanoidRootPart:FindFirstChild("RootJoint")
	end

	return rootJoint, neck, leftShoulder, leftHip, rightShoulder, rightHip
end

--- TODO : Enable param
function Gears.DisableJoints(character)
	-- Disable Joints
	for Index, Child in pairs(character:GetChildren()) do
		local isInBanList = Child.Name == "Neck" -- TODO : BanList

		if Child:IsA("Motor6D") and not isInBanList then
			Child.Enabled = false
		end

		-- Recursive
		if #Child:GetChildren() > 0 then
			Gears.DisableJoints(Child)
		end
	end
end

function Gears.EnableJointInstantly(joint: Motor6D, d)
	-- joint.Enabled = true

	local parentPart = joint.Part0
	local childPart = joint.Part1

	if not parentPart or not childPart then
		warn("Enable Joint Instantly : Missing Parent or Child Part")
		return
	end

	-- Reset Child Pos
	-- local targetCFrame = parentPart.CFrame * joint.C0 * joint.C1:Inverse()
	local targetCFrame = parentPart:GetPivot() * joint.C1
	-- local targetCFrame = parentPart.CFrame * joint.C1
	childPart.CFrame = targetCFrame

	if d then
		warn(childPart.Name .. " Target Position = ")
		warn(targetCFrame.Position)

		-- warn(childPart.Name .. " Target Rotation = ")
		-- warn(targetCFrame.Rotation)
	end

	-- Reset Physics
	childPart.AssemblyLinearVelocity = Vector3.zero
	childPart.AssemblyAngularVelocity = Vector3.zero
end

---@param character Model
function Gears.Dismember(character)
	Gears.DisableJoints(character)

	local torso, head, leftArm, leftLeg, rightArm, rightLeg = Gears.GetBodyParts(character)

	character.HumanoidRootPart.Anchored = true
	torso.CanCollide = true
	head.CanCollide = true
	leftArm.CanCollide = true
	leftLeg.CanCollide = true
	rightArm.CanCollide = true
	rightLeg.CanCollide = true
end

--- Reset a Dismembered Character
---@param character Model
function Gears.ResetCharacter(character)
	-- Get Body Parts
	local torso, head, leftArm, leftLeg, rightArm, rightLeg = Gears.GetBodyParts(character)
	local HumanoidRootPart = character.HumanoidRootPart

	-- Get Joints
	local rootJoint, neck, leftShoulder, leftHip, rightShoulder, rightHip = Gears.GetJoints(character)

	HumanoidRootPart.Anchored = false

	-- Enable Joints
	rootJoint.Enabled = true
	neck.Enabled = true
	leftShoulder.Enabled = true
	leftHip.Enabled = true
	rightShoulder.Enabled = true
	rightHip.Enabled = true

	-- Reset Pos
	-- local localOffset = CFrame.new(0, 0, 0)
	-- torso.CFrame = character:GetPivot() * localOffset
	-- HumanoidRootPart.CFrame = character:GetPivot() * localOffset

	-- Gears.EnableJointInstantly(rootJoint, d)
	-- Gears.EnableJointInstantly(neck, d)
	-- Gears.EnableJointInstantly(leftShoulder, d)
	-- Gears.EnableJointInstantly(leftHip, d)
	-- Gears.EnableJointInstantly(rightShoulder, d)
	-- Gears.EnableJointInstantly(rightHip, d)

	-- Enable Collisions
	-- HumanoidRootPart.CanCollide = true
	torso.CanCollide = true
	head.CanCollide = true
	leftArm.CanCollide = true
	leftLeg.CanCollide = true
	rightArm.CanCollide = true
	rightLeg.CanCollide = true
end

-- #endregion

-- #region UI

--- Converte Seconds to minutes:seconds format
function Gears.ToMS(seconds)
	return string.format("%02i:%02i", seconds / 60, seconds % 60)
end

function Gears.UpdateBar(bar, percent)
	local usePercent = math.max(0, percent)
	bar.Size = UDim2.fromScale(usePercent, 1)
end

-- Placing Elements + Offsets/Gaps in a frame :
-- Goal = find cellSize for perfect fit
-- x = cellSize, y = columns, z -> offset size = cellSize * z%, Frame horizontal space = 1
-- 1 = x * y + x * z * y -> Solve equation for x

-- 1] Side Offsets
-- 1 = x * y + x * z * (y + 1)

-- 2] No Side Offsets
-- 1 = x * y + x * z * (y - 1)

-- eg : No Side Offsets 3 Elements
-- y = 3, z = 0.5
-- 1 = x * 3 + x * 0.5 * (3 - 1) -> 1 = 3x + 1x
-- -> x = 1 / 4 = 0.25
function Gears.ElementXSize(hasSideGaps, columns, gapSize)
	local divisor = hasSideGaps and columns + gapSize * (columns + 1) or columns + gapSize * (columns - 1)
	local elementXSize = 1 / divisor
	return elementXSize
end

-- #endregion

-- #region AUDIO

function Gears.SafePlaySound(sound)
	sound:Stop()
	sound.TimePosition = 0
	task.wait()
	sound:Play()
end

function Gears.SafePlaySoundClone(soundPrefab, parent)
	local sound = soundPrefab:Clone()
	sound.Parent = parent
	task.wait()
	sound:Play()
	game.Debris:AddItem(sound, sound.TimeLength + 0.01)
end

-- #endregion

-- #region ASYNC LOGIC

function Gears.ExecuteFor(duration, lambda)
	local execute = RunService.Heartbeat:Connect(function()
		lambda()
	end)

	task.delay(duration, function()
		execute:Disconnect()
	end)
end

function Gears.WaitUntil(condition)
	local startTime = tick()
	local timeout = 10

	while not condition() do
		task.wait()

		if tick() - startTime > timeout then
			warn("waitUntil timed out!")
			return false
		end
	end

	return true
end

-- #endregion

-- #region DEBUG & PERF

-- Simple test
function Gears.PerformanceTest(lambda)
	print("Performance Test START : " .. tick())
	lambda()
	print("Performance Test END : " .. tick())
end

function Gears.DrawEdge(startPos, endPos, color)
	local adorn = Instance.new("LineHandleAdornment")
	adorn.Length = (endPos - startPos).Magnitude
	adorn.Color3 = color or Color3.new(0, 1, 0)
	adorn.Thickness = 20
	adorn.Adornee = workspace.Terrain
	-- Position it at origin and point it toward the direction
	adorn.CFrame = CFrame.lookAt(startPos, endPos)
	adorn.AlwaysOnTop = true
	adorn.Parent = workspace.Terrain

	game.Debris:AddItem(adorn, 0.01)
end

function Gears.DrawRay(origin, direction, color)
	Gears.DrawEdge(origin, origin + direction, color)
end

function Gears.DrawCircle(basePos, circlePoints)
	local function drawEdge(point1, point2)
		local startPos = basePos + Vector3.new(point1.X, 0, point1.Y)
		local endPos = basePos + Vector3.new(point2.X, 0, point2.Y)
		Gears.DrawEdge(startPos, endPos)
	end

	-- Draw Edges
	for index = 1, #circlePoints - 1, 1 do
		drawEdge(circlePoints[index], circlePoints[index + 1])
	end

	-- Draw Last Edges : Last Point -> First
	drawEdge(circlePoints[#circlePoints], circlePoints[1])
end

function Gears.DrawSphere(position, radius, color)
	local adorn = Instance.new("SphereHandleAdornment")
	adorn.Radius = radius
	adorn.Color3 = color or Color3.new(0.5, 0, 0)
	adorn.Transparency = 0.5
	adorn.Adornee = workspace.Terrain -- Must be attached to something
	adorn.CFrame = CFrame.new(position)
	adorn.AlwaysOnTop = true
	adorn.Parent = workspace.Terrain

	game.Debris:AddItem(adorn, 0.01)
end

-- #endregion

-- #region MATH

Gears.MAX_RAD = math.pi * 2

--- Get the Magnitude of a Vector before SquareRoot
function Gears.SquaredMagnitude(vector3)
	return (vector3.X * vector3.X) + (vector3.Y * vector3.Y) + (vector3.Z * vector3.Z)
end

--- eg 10% Increase -> 1.1
function Gears.IncreaseToMultiplier(increaseValue)
	return 1 + increaseValue / 100
end

function Gears.FloatRandom(minNbr, maxNbr)
	local randomDecimal = math.random(1, 10) / 10
	return math.random(minNbr, maxNbr - 1) + randomDecimal
end

function Gears.RandomRange(defaultValue, range)
	local minValue = defaultValue
	local maxValue = minValue + range
	local value = math.random(minValue, maxValue)

	return value
end

function Gears.LoopValue(value, max, resetValue) -- TODO : Add min
	local resetValue2 = resetValue or 0

	if value > max then
		value = resetValue2
	end

	return value
end

function Gears.Sigmoid(x, slop, length)
	local useSlop = slop or 1
	local useLength = length or 1
	return useLength / (useLength + math.exp(useSlop * x))
end

-- #endregion

-- #region GEOMETRY

--- Get random points within a Circle
function Gears.GetPosWithinCircle(outerRadius, amount, constraints)
	local positions = {}
	local useConstraints = constraints or {}

	for i = 1, amount do
		local radius = Gears.FloatRandom(0, outerRadius)
		local progress = Gears.FloatRandom(0, Gears.MAX_RAD)

		local point = Gears.CirclePos(radius, progress)

		-- Apply Constraints
		for j = 1, #useConstraints do
			point = useConstraints[j](point)
		end

		positions[i] = point
	end

	return positions
end

--- Get random points within 2 Circles -> Inner Circle is at the Center of Outer Circle
function Gears.GetPosWithinCircles(innerRadius, outerRadius, amount)
	local positions = {}

	for i = 1, amount do
		local radius = Gears.FloatRandom(innerRadius, outerRadius)
		local progress = Gears.FloatRandom(0, Gears.MAX_RAD)

		positions[i] = Gears.CirclePos(radius, progress)
	end

	return positions
end

--- Get the Magnitude of a Vector
function Gears.PointsDistance(pointA, pointB)
	return (pointA - pointB).Magnitude
end

--- Normalize a 2D Vector
function Gears.NormalizeOrZero(vector2)
	if vector2 == Vector2.zero then
		return Vector2.zero
	end

	return vector2.Unit
end

--- Get a Point on a Parabolla
function Gears.ParabolaPos(startPos, endPos, height, progress)
	-- DEBUG
	-- TODO : Gears.DrawSphere(startPos, 1, Color3.fromRGB(48, 62, 12))
	-- Gears.DrawSphere(finalTargetPos, 1, Color3.fromRGB(82, 221, 112))

	local lerpPos = startPos + (endPos - startPos) * progress
	-- local y = startPos.Y + (height * 4 * progress * (1 - progress)) -- End up at startPos Y
	local y = endPos.Y + (height * 4 * progress * (1 - progress))
	return Vector3.new(lerpPos.X, y, lerpPos.Z)
end

--- Use Over time :
--- progress = (progress + 0.01) % (math.pi * 2)
function Gears.CirclePos(radius, progress)
	local x = math.cos(progress) * radius
	local y = math.sin(progress) * radius
	return Vector2.new(x, y) -- Add to a position
end

--- Get X Points on a Circle
function Gears.CirclePoints(radius, division) -- TODO : Add Progress
	local points = {}
	local pointDistance = (math.pi * 2) / division

	for i = 0, (division - 1), 1 do
		table.insert(points, Gears.CirclePos(radius, pointDistance * i))
	end

	return points
end

--- Use Over time :
--- latitude = (progress + 0.01) % (math.pi * 2)
--- longitude = (progress + 0.01) % (math.pi * 2)
function Gears.SpherePos(latitude, longitude, radius)
	local x = math.sin(latitude) * math.cos(longitude) * radius
	local y = math.sin(latitude) * math.sin(longitude) * radius
	local z = math.cos(latitude) * radius
	return Vector3.new(x, y, z) -- Add to a position
end

-- #endregion

return Gears
