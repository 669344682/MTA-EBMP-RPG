------------------------------------------------------
--
-- c_hud_mask.lua
--

----------------------------------------------------------------
-- onClientResourceStart
----------------------------------------------------------------
addEventHandler( "onClientResourceStart", resourceRoot,
	function()
		-- Create things
		hudMaskShader = dxCreateShader("hud_mask.fx")
		radarTexture = dxCreateTexture("images/radar.jpg")
		maskTexture1 = dxCreateTexture("images/circle_mask.png")
		maskTexture2 = dxCreateTexture("images/sept_mask.png")

		setPlayerHudComponentVisible("radar", false)
		setPlayerHudComponentVisible ("area_name", false )
		setPlayerHudComponentVisible ("armour", false )

		-- Check everything is ok
		bAllValid = hudMaskShader and radarTexture and maskTexture1 and maskTexture2

		if not bAllValid then
			outputChatBox( "Could not create some things. Please use debugscript 3" )
		else
			dxSetShaderValue( hudMaskShader, "sPicTexture", radarTexture )
			dxSetShaderValue( hudMaskShader, "sMaskTexture", maskTexture1 )
		end
end)

function getSpeed(vehicle)
	if vehicle then
		local x, y, z = getElementVelocity(vehicle)
		return math.sqrt(math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2))*111.847--*1.61--узнает скорость авто в км/ч
	end
end

function findRotation(x1,y1,x2,y2)
local t = -math.deg(math.atan2(x2-x1,y2-y1))
if t < 0 then t = t + 360 end
return t
end

function getDistanceRotation(x, y, dist, angle)
local a = math.rad(90 - angle)
local dx = math.cos(a) * dist
local dy = math.sin(a) * dist
return x+dx, y+dy
end

function getPedMaxHealth(ped)
	-- Output an error and stop executing the function if the argument is not valid
	assert(isElement(ped) and (getElementType(ped) == "ped" or getElementType(ped) == "player"), "Bad argument @ 'getPedMaxHealth' [Expected ped/player at argument 1, got " .. tostring(ped) .. "]")

	-- Grab his player health stat.
	local stat = getPedStat(ped, 24)

	-- Do a linear interpolation to get how many health a ped can have.
	-- Assumes: 100 health = 569 stat, 200 health = 1000 stat.
	local maxhealth = 100 + (stat - 569) / 4.31

	-- Return the max health. Make sure it can't be below 1
	return math.max(1, maxhealth)
end

-----------------------------------------------------------------------------------
-- onClientRender
-----------------------------------------------------------------------------------
local screenWidth, screenHeight = guiGetScreenSize ( )
local sx,sy = screenWidth, screenHeight
local posx = screenWidth-136
local posy = screenHeight-151
local height = 126
local centerleft = posx + height / 2
local centertop = posy + height / 2
local lp = getLocalPlayer()
local range = 230
addEventHandler( "onClientRender", root,
	function()
		if not bAllValid or not getElementData(localPlayer, "radar_visible") then return end

		--
		-- Switch between mask textures every few seconds for DEMO
		--
		--[[if getTickCount() % 3000 < 2000 then
			dxSetShaderValue( hudMaskShader, "sMaskTexture", maskTexture1 )
		else
			dxSetShaderValue( hudMaskShader, "sMaskTexture", maskTexture2 )
		end]]

		--
		-- Transform world x,y into -0.5 to 0.5
		--
		local x,y = getElementPosition(localPlayer)
		x = ( x ) / 6000
		y = ( y ) / -6000
		dxSetShaderValue( hudMaskShader, "gUVPosition", x,y )

		--
		-- Zoom
		--
		local zoom = 13
		--zoom = zoom + math.sin( getTickCount() / 500 ) * 3		-- Zoom animation for DEMO
		dxSetShaderValue( hudMaskShader, "gUVScale", 1/zoom, 1/zoom )

		--
		-- Rotate to camera direction - OPTIONAL
		--
		local _,_,camrot = getElementRotation( getCamera() )
		local _,_,playerrot = getElementRotation( localPlayer )
		dxSetShaderValue( hudMaskShader, "gUVRotAngle", math.rad(-camrot) )

		--
		-- Draw
		--
		dxDrawImage( screenWidth-146, screenHeight-161, 146, 146, "images/radar_ver1.png", 0,0,0, tocolor(255,255,255,255) )
		dxDrawCircle ( (screenWidth-146)+(146/2), (screenHeight-161)+(146/2), 72, 83.0, (-166.0/getPedMaxHealth(localPlayer))*getElementHealth(localPlayer)+83, tocolor( 111,154,104,255 ), tocolor( 111,154,104,255 ) )
		dxDrawCircle ( (screenWidth-146)+(146/2), (screenHeight-161)+(146/2), 72, 97.0, (166.0/100)*getPedArmor(localPlayer)+97, tocolor( 0, 102, 255,255 ), tocolor( 0, 102, 255,255 ) )
		dxDrawImage( screenWidth-136, screenHeight-151, 126, 126, hudMaskShader, 0,0,0, tocolor(255,255,255,255) )
		dxDrawImage( screenWidth-146, screenHeight-161, 146, 146, "images/radar_ver2.png", 0,0,0, tocolor(255,255,255,255) )
		dxDrawImage( screenWidth-146, screenHeight-161, 146, 146, "images/pointer.png", camrot,0,0, tocolor(255,255,255,255) )
		
		--blips
		local px, py, pz = getElementPosition(lp)
		local cx,cy,_,tx,ty = getCameraMatrix()
		local north = findRotation(cx,cy,tx,ty)
		for id, v in ipairs(getElementsByType("blip")) do
			local _,_,rot = getElementRotation(v)
			local ex, ey, ez = getElementPosition(v)
			local dist = getDistanceBetweenPoints2D(px,py,ex,ey)
			local blipdist = getBlipVisibleDistance (v)

			if dist > range then
				dist = tonumber(range)
			end

			local angle = 180-north + findRotation(px,py,ex,ey)
			local cblipx, cblipy = getDistanceRotation(0,0, (height/2)*(dist/range), angle)
			local icon=getBlipIcon(v) or 0
			local blipsize=(getBlipSize(v)*2 or 2)*4
			local r,g,b,a=getBlipColor(v)
			
			if icon~=0 then
				r,g,b=255,255,255
				blipsize=16
			end

			local blipx = centerleft+cblipx-(blipsize/2)
			local blipy = centertop+cblipy-(blipsize/2)

			if (getDistanceBetweenPoints3D ( px, py, pz, ex, ey, ez ) <= blipdist ) then
				dxDrawImage(blipx, blipy, blipsize, blipsize, "images/blips/"..icon..".png", 0, 0, 0, tocolor(r,g,b,a))
			end
		end
		dxDrawImage( screenWidth-(146/2)-8, screenHeight-(146/2)-8-15, 16, 16, "images/blips/2.png", -playerrot+camrot,0,0, tocolor(255,255,255,255) )
	end
)