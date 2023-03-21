local g_version = "2.2.0"

-------------------------------------------------------------------------------
print("-------------- BBS UI v"..g_version.." -D- Init --------------")
-------------------------------------------------------------------------------

function OnLocalPlayerTurnBegin()

	if Game.GetLocalPlayer() == -1 then
		return
	end
	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		print("BBS UI Welcome")
		local message = "BBS #"..GetLocalModVersion("c88cba8b-8311-4d35-90c3-51a4a5d66550").." loaded succesfully!"
		

		if (Game:GetProperty("BBS_RESPAWN") == false) then
			message = message.." Firaxis Placement Algorithm has been used."
		else
			message = message.." BBS Placement Algorithm has been used."
			print(Game:GetProperty("BBS_ITERATION"),Game:GetProperty("BBS_MAJOR_DISTANCE"))
			if (Game:GetProperty("BBS_ITERATION") ~= nil) and (Game:GetProperty("BBS_MAJOR_DISTANCE") ~= nil) then
				message = message..tostring(Game:GetProperty("BBS_ITERATION")).." Attempt(s), Min Distance is "..tostring(Game:GetProperty("BBS_MAJOR_DISTANCE"))	
			end
		end	
		NotificationManager.SendNotification(Game.GetLocalPlayer(), NotificationTypes.USER_DEFINED_5, message);
		if (Game:GetProperty("BBS_DISTANCE_ERROR") ~= nil) then
			message = tostring(Game:GetProperty("BBS_DISTANCE_ERROR"))
			NotificationManager.SendNotification(Game.GetLocalPlayer(), NotificationTypes.BARBARIANS_SIGHTED, message);
		end
		if (Game:GetProperty("BBS_MINOR_FAILING_TOTAL") ~= nil) then
			message = tostring(Game:GetProperty("BBS_MINOR_FAILING_TOTAL")).." CS had to be razed to observe minimum distances requirements."
			NotificationManager.SendNotification(Game.GetLocalPlayer(), NotificationTypes.BARBARIANS_SIGHTED, message);
		end		

		
	end
	
	
end


Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin);


-- ===========================================================================
function GetLocalModVersion(id)
	if id == nil then
		return nil
	end
	
	local mods = Modding.GetInstalledMods();
	if(mods == nil or #mods == 0) then
		print("No mods locally installed!")
		return nil
	end
	
	local handle = -1
	for i,mod in ipairs(mods) do
		if mod.Id == id then
			handle = mod.Handle
			break
		end
	end
	if handle ~= -1 then
		local version = Modding.GetModProperty(handle, "Version");
		print("id",id,version)
		return version
		else
		return nil
	end
	
	
end