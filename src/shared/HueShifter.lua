--!strict
-- Made by Staral

--[[
	Services
]]
local RunService = game:GetService("RunService")

--[[
	Module decleration
]]
local Container = {}

--[[
	Class container
]]
local HueShifter = {}
HueShifter.__index = HueShifter

--[[
	Types
]]
export type HueShifter = typeof(setmetatable({} :: {

	CycleTime : number,
	Playing : boolean,
	PlayConnection : RBXScriptConnection?,
	Parent : Instance,

	Counter : number,

	IgnoreClasses : {string}?,
	IgnoreTag : string?

}, {__index = HueShifter}))

export type HueShifterInfo = {
	CycleTime : number?,
	IgnoreClasses : {string}?,
	IgnoreTag : string?,
}

--[[
	Data for which classes can be colored what
]]
local ColorChangableNonSequential = {"BasePart", "PointLight", "SpotLight", "SurfaceLight", "Part", "MeshPart", "UIGradient", "UIStroke", "UnionOperation", "IntersectOperation"}
local ColorChangableSequential = {"ParticleEmitter", "Beam", "Trail"}
local ColorChangableValue = {"Color3Value"}
local ColorChangableVector = {"SpecialMesh"}
local ColorChangableText = {"TextLabel", "TextButton"}
local ColorChangableImage = {"ImageLabel", "ImageButton"}
local ColorChangableFrame = {"Frame", "ImageLabel", "ImageButton", "TextLabel", "TextButton"}
local ColorChangableDecal = {"Decal", "Texture"}

--[[
	Extended classes
]]
local ColorExtention = {}
--[[
	Creates a Color3 from a Vector3
]]
function ColorExtention.fromVector3(Input : Vector3) : Color3
	assert(Input, "No input given to create Color3 from")

	local self = Color3.new(Input.X, Input.Y, Input.Z)
	return self	
end

local VectorExtention = {}
--[[
	Creates a Vector3 from a Color3
]]
function VectorExtention.fromColor3(Input : Color3) : Vector3
	assert(Input, "No input given to create Vector3 from")

	local self = Vector3.new(Input.R, Input.G, Input.B)
	return self
end

local Color3 = setmetatable(ColorExtention, {__index = Color3})
local Vector3 = setmetatable(VectorExtention, {__index = Vector3})

--[[
	Global functions
]]

--[[
	A global function to build the HueShifter.
	
	This functionality could be moved to the HueShifter new function
	It's up here--near the types--to make it easier to access and read.
]]
local function ConstructHueShifter(Parent : Instance, HueShifterInfo : HueShifterInfo) : HueShifter
	local self : HueShifter = setmetatable({

		CycleTime = HueShifterInfo.CycleTime or 1,
		Playing = true,
		Counter = 0,
		Parent = Parent,
		IgnoreClasses = HueShifterInfo.IgnoreClasses,
		IgnoreTag = HueShifterInfo.IgnoreTag

	}, HueShifter)

	return self
end

--[[
	A global function that returns the proper event for weither it's
	being ran on the server of the client.
	
	No need to alter the module depending on context.
]]
local function GetSteppedEvent() : RBXScriptSignal
	if (RunService:IsServer()) then
		return RunService.Heartbeat	
	end

	return RunService.RenderStepped
end


--[[
	Generic Hue Shift function for all of your hue shifting needs
	
	Yes this is recursive but it doesn't ever need to go through itself
	more than once so it's all cool 8)
	
	Buy me the "i <3 any casting" shirt
]]
local function HueShift<T>(Color : T, Alpha : number) : T

	if (typeof(Color) == "Color3") then

		local Color : Color3 = Color
		local hue, sat, val = Color:ToHSV()
		return Color3.fromHSV((hue + Alpha) % 1, sat, val) :: any

	elseif (typeof(Color) == "Vector3") then

		local Color : Vector3 = Color
		local translatedColor = Color3.fromVector3(Color)
		local shiftedColor = HueShift(translatedColor, Alpha)
		return Vector3.fromColor3(shiftedColor) :: any

	elseif (typeof(Color) == "ColorSequence") then

		local Color : ColorSequence = Color

		local newKeypoints : {ColorSequenceKeypoint} = {}
		for _, v in Color.Keypoints do
			table.insert(newKeypoints, ColorSequenceKeypoint.new(v.Time, HueShift(v.Value, Alpha)))
		end

		return ColorSequence.new(newKeypoints) :: any
	end

	error("Unable to Hue Shift this type")
end

--[[
	A global function for sorting and assigning new colors to all
	of the objects under the Parent that need to be changed.
	
	It uses the info tables at the top.
]]
local function HueShiftObjects(Actors : {Instance}, Alpha : number, IgnoreClasses : {string}?, IgnoreTag : string?)
	for _, v in Actors do

		if not (v) then continue end

		if (IgnoreTag and v:HasTag(IgnoreTag)) then continue end
		if (IgnoreClasses) then
			local isIgnored = false

			for _, class in IgnoreClasses do
				if (v:IsA(class)) then isIgnored = true end
			end

			if (isIgnored) then continue end
		end

		--[[
			shut up roblox I'm safe
		]]
		local vTypeSafe = v :: any

		local properties : {string} = {}

		if (table.find(ColorChangableNonSequential, v.ClassName) or table.find(ColorChangableSequential, v.ClassName)) then
			table.insert(properties, "Color")
		end

		if (table.find(ColorChangableValue, v.ClassName)) then
			table.insert(properties, "Value")
		end

		if (table.find(ColorChangableVector, v.ClassName)) then	
			table.insert(properties, "VertexColor")
		end

		if (table.find(ColorChangableText, v.ClassName)) then
			table.insert(properties, "TextColor3")
			table.insert(properties, "TextStrokeColor3")
		end

		if (table.find(ColorChangableImage, v.ClassName)) then
			table.insert(properties, "ImageColor3")
		end

		if (table.find(ColorChangableFrame, v.ClassName)) then
			table.insert(properties, "BackgroundColor3")
			table.insert(properties, "BorderColor3")
		end
		
		if (table.find(ColorChangableDecal, v.ClassName)) then
			table.insert(properties, "Color3")
		end

		for _, property : string in properties do
			local originalColor = v:GetAttribute("__"..property)
			if not (originalColor) then
				v:SetAttribute("__"..property, vTypeSafe[property])
			end

			local shifted = HueShift(originalColor or vTypeSafe[property], Alpha)
			vTypeSafe[property] = shifted

			-- 🧠 Sync BrickColor if we're modifying the Color property
			if property == "Color" and v:IsA("BasePart") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
				vTypeSafe.BrickColor = BrickColor.new(shifted)
			end
		end

	end
end

--[[
	Class methods
]]

--[[
	Sets the Playing property accordingly and activates
	the functionality of the HueShifter if it hasn't already.
]]
function HueShifter.Play(self : HueShifter)
	self.Playing = true

	if (not self.PlayConnection) then
		self.Counter = 0

		--[[
			HueShifter per-frame functionality.
		]]
		self.PlayConnection = GetSteppedEvent():Connect(function(deltaTime : number)
			if (not self.Parent) then self:Stop() return end
			if (not self.Playing) then return end

			self.Counter = (self.Counter + (deltaTime/self.CycleTime)) % 1

			HueShiftObjects(self.Parent:GetDescendants(), self.Counter, self.IgnoreClasses, self.IgnoreTag)
		end)

	end
end

--[[
	Sets the Plaing property accordingly and deactivates
	the functionality of the HueShifter as to not cause
	memory leaks.
]]
function HueShifter.Stop(self : HueShifter)
	self.Playing = false

	if (self.PlayConnection) then
		self.PlayConnection:Disconnect()
		self.PlayConnection = nil	
	end
end

function HueShifter.Pause(self : HueShifter)
	self.Playing = false
end


--[[
	Constructor methods
]]

--[[
	Constructs a new HueShifter from a Parent.
]]
function Container.new(Parent : Instance, HueShifterInfo : HueShifterInfo) : HueShifter
	assert(Parent, "No Parent has been provided.")
	assert(HueShifterInfo, "No HueShifterInfo has been provided.")

	local self = ConstructHueShifter(Parent, HueShifterInfo)
	return self
end

--[[
	Constructs a new glorified dictionary 
	
	*cough cough* 
	
	I mean HueShifterInfo.
]]
function Container.CreateInfo(CycleTime : number?, IgnoreClasses : {string}?, IgnoreTag : string) : HueShifterInfo
	local self : HueShifterInfo = {
		CycleTime = CycleTime,
		IgnoreClasses = IgnoreClasses,
		IgnoreTag = IgnoreTag
	}

	return self
end

--[[
	Return the module
]]
return Container
