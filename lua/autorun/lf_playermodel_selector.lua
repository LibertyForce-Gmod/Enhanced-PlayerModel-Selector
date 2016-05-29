-- Enhanced PlayerModel Selector
-- Upgraded code by LibertyForce http://steamcommunity.com/id/libertyforce
-- Based on: https://github.com/garrynewman/garrysmod/blob/1a2c317eeeef691e923453018236cf9f66ee74b4/garrysmod/gamemodes/sandbox/gamemode/editor_player.lua


if SERVER then


AddCSLuaFile()

util.AddNetworkString("lf_playermodel_cvar_sync")
util.AddNetworkString("lf_playermodel_cvar_change")
util.AddNetworkString("lf_playermodel_blacklist")
util.AddNetworkString("lf_playermodel_update")

local convars = { }
convars["sv_playermodel_selector_force"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_gamemodes"]	= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_instantly"]	= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_flexes"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_blacklist"]	= { "", bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }

for cvar, v in pairs( convars ) do
	CreateConVar( cvar,	v[1], v[2] )
end

hook.Add( "PlayerAuthed", "lf_playermodel_cvar_sync_hook", function( ply )
	local tbl = { }
	for cvar in pairs( convars ) do
		tbl[cvar] = GetConVar(cvar):GetInt()
	end
	net.Start("lf_playermodel_cvar_sync")
	net.WriteTable( tbl )
	net.Send( ply )
end )

net.Receive("lf_playermodel_cvar_change", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() then
		local cvar = net.ReadString()
		if !convars[cvar] then ply:Kick("Illegal convar change") return end
		if !ply:IsAdmin() then return end
		RunConsoleCommand( cvar, net.ReadString() )
	end
end )


local Blacklist = { }
if file.Exists( "playermodel_selector_blacklist.txt", "DATA" ) then
	local loaded = util.JSONToTable( file.Read( "playermodel_selector_blacklist.txt", "DATA" ) )
	if istable( loaded ) then
		for k, v in pairs( loaded ) do
			Blacklist[tostring(k)] = v
		end
	end
end

net.Receive("lf_playermodel_blacklist", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() then
		local mode = net.ReadInt( 3 )
		if mode == 1 then
			local gamemode = net.ReadString()
			if gamemode != "sandbox" then
				Blacklist[gamemode] = true
				file.Write( "playermodel_selector_blacklist.txt", util.TableToJSON( Blacklist, true ) )
			end
		elseif mode == 2 then
			local tbl = net.ReadTable()
			if istable( tbl ) then
				for k, v in pairs( tbl ) do
					local name = tostring( v )
					Blacklist[v] = nil
				end
				file.Write( "playermodel_selector_blacklist.txt", util.TableToJSON( Blacklist, true ) )
			end
		end
		net.Start("lf_playermodel_blacklist")
		net.WriteTable( Blacklist )
		net.Send( ply )
	end
end )

local legs_installed = false
if file.Exists( "autorun/sh_legs.lua", "LUA" ) then legs_installed = true end

local plymeta = FindMetaTable( "Player" )

local function Allowed( ply )
	if GAMEMODE_NAME == "sandbox" or ( !Blacklist[GAMEMODE_NAME] and ( ply:IsAdmin() or GetConVar( "sv_playermodel_selector_gamemodes"):GetBool() ) ) then
		return true	else return false
	end
end


local function UpdatePlayerModel( ply )
	if Allowed( ply ) then
	
		local mdlname = ply:GetInfo( "cl_playermodel" )
		
		local rmodelscvar = GetConVar( "sv_playermodel_selector_blacklist" ):GetString()
		
		if rmodelscvar!="" then
			
			local restricted_models_list = string.Explode( ",", rmodelscvar )
			
			if table.HasValue( restricted_models_list, mdlname ) then return end
			
		end
		
		local mdlpath = player_manager.TranslatePlayerModel( mdlname )
		
		ply:LF_SetModel( mdlpath )
		
		local skin = ply:GetInfoNum( "cl_playerskin", 0 )
		ply:SetSkin( skin )
		
		local groups = ply:GetInfo( "cl_playerbodygroups" )
		if ( groups == nil ) then groups = "" end
		local groups = string.Explode( " ", groups )
		for k = 0, ply:GetNumBodyGroups() - 1 do
			ply:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
		end
		
		if GetConVar( "sv_playermodel_selector_flexes" ):GetBool() and tobool( ply:GetInfoNum( "cl_playermodel_selector_unlockflexes", 0 ) ) then
			local flexes = ply:GetInfo( "cl_playerflexes" )
			if ( flexes == nil ) then flexes = "" end
			local flexes = string.Explode( " ", flexes )
			for k = 0, ply:GetFlexNum() - 1 do
				ply:SetFlexWeight( k, tonumber( flexes[ k + 1 ] ) or 0 )
			end
		end
		
		local pcol = ply:GetInfo( "cl_playercolor" )
		local wcol = ply:GetInfo( "cl_weaponcolor" )
		ply:SetPlayerColor( Vector( pcol ) )
		ply:SetWeaponColor( Vector( wcol ) )
		
		timer.Simple( 0.2, function()
			local oldhands = ply:GetHands()
			if ( IsValid( oldhands ) ) then oldhands:Remove() end
			local hands = ents.Create( "gmod_hands" )
			if ( IsValid( hands ) ) then
				ply:SetHands( hands )
				hands:SetOwner( ply )
				-- Which hands should we use?
				local info = player_manager.TranslatePlayerHands( mdlname )
				if ( info ) then
					hands:SetModel( info.model )
					hands:SetSkin( info.skin )
					hands:SetBodyGroups( info.body )
				end
				-- Attach them to the viewmodel
				local vm = ply:GetViewModel( 0 )
				hands:AttachToViewmodel( vm )
				vm:DeleteOnRemove( hands )
				ply:DeleteOnRemove( hands )
				hands:Spawn()
			end
		end )
		
		if legs_installed then
			ply:ConCommand( "cl_refreshlegs" )
		end
		
	end
end

net.Receive("lf_playermodel_update", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( ply:IsAdmin() or GetConVar( "sv_playermodel_selector_instantly"):GetBool() ) then
		UpdatePlayerModel( ply )
	end
end )

hook.Add( "PlayerSpawn", "lf_playermodel_force_hook1", function( ply )
	if GetConVar( "sv_playermodel_selector_force" ):GetBool() and tobool( ply:GetInfoNum( "cl_playermodel_selector_force", 0 ) ) then
		UpdatePlayerModel( ply )
	end
end )

hook.Add( "PlayerSetModel", "lf_playermodel_force_hook2", function( ply )
	if GetConVar( "sv_playermodel_selector_force" ):GetBool() and Allowed( ply ) and tobool( ply:GetInfoNum( "cl_playermodel_selector_force", 0 ) ) then
		return false
	end
end )

local function ToggleForce()
	if GetConVar( "sv_playermodel_selector_force" ):GetBool() then
		plymeta.SetModel = function( ply, mdl )
			if Allowed( ply ) and tobool( ply:GetInfoNum( "cl_playermodel_selector_force", 0 ) ) then
			else
				ply:LF_SetModel( mdl )
			end
		end
	else
		plymeta.SetModel = nil
	end
end
cvars.AddChangeCallback( "sv_playermodel_selector_force", ToggleForce )
plymeta.LF_SetModel = plymeta.LF_SetModel or FindMetaTable("Entity").SetModel
ToggleForce()


end

-----------------------------------------------------------------------------------------------------------------------------------------------------

if CLIENT then


local Menu = { }
local Frame
local default_animations = { "idle_all_01", "menu_walk" }
local Favorites = { }
local flexes_unlocked = false
local restricted_models = {}

if file.Exists( "playermodel_selector_favorites.txt", "DATA" ) then
	local loaded = util.JSONToTable( file.Read( "playermodel_selector_favorites.txt", "DATA" ) )
	if istable( loaded ) then
		for k, v in pairs( loaded ) do
			Favorites[tostring(k)] = v
		end
	end
end


CreateClientConVar( "cl_playermodel_selector_force", "1", true, true )
CreateClientConVar( "cl_playermodel_selector_unlockflexes", "0", false, true )
CreateClientConVar( "cl_playermodel_selector_bgcolor_custom", "1", true, true )

net.Receive("lf_playermodel_cvar_sync", function()
	local tbl = net.ReadTable()
	for k, v in pairs( tbl ) do
		CreateConVar( k, v, { FCVAR_REPLICATED } )
	end
end )

hook.Add( "PostGamemodeLoaded", "lf_playermodel_sboxcvars", function()
	if !ConVarExists( "cl_playercolor" ) then CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" ) end
	if !ConVarExists( "cl_weaponcolor" ) then CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" ) end
	if !ConVarExists( "cl_playerskin" ) then CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" ) end
	if !ConVarExists( "cl_playerbodygroups" ) then CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" ) end
	if !ConVarExists( "cl_playerflexes" ) then CreateConVar( "cl_playerflexes", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The flexes to use, if the model has any" ) end
end )


local function KeyboardOn( pnl )
	if ( IsValid( Frame ) and IsValid( pnl ) and pnl:HasParent( Frame ) ) then
		Frame:SetKeyboardInputEnabled( true )
	end
end
hook.Add( "OnTextEntryGetFocus", "lf_playermodel_keyboard_on", KeyboardOn )
local function KeyboardOff( pnl )
	if ( IsValid( Frame ) and IsValid( pnl ) and pnl:HasParent( Frame ) ) then
		Frame:SetKeyboardInputEnabled( false )
	end
end
hook.Add( "OnTextEntryLoseFocus", "lf_playermodel_keyboard_off", KeyboardOff )


function Menu.Setup()

	Frame = vgui.Create( "DFrame" )
	local fw, fh = 960, 700
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Enhanced PlayerModel Selector" )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:SetScreenLock( true )
	Frame:ShowCloseButton( true )
	Frame:Center()
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	local r, g, b = 97, 100, 102
	if GetConVar( "cl_playermodel_selector_bgcolor_custom" ):GetBool() then
		local bgcolor = string.Explode( " ", GetConVar( "cl_playercolor" ):GetString() )
		bgcolor[1] = tonumber( bgcolor[1] )
		bgcolor[2] = tonumber( bgcolor[2] )
		bgcolor[3] = tonumber( bgcolor[3] )
		if isnumber( bgcolor[1] ) and isnumber( bgcolor[2] ) and isnumber( bgcolor[3] ) then
			r, g, b = math.Round( bgcolor[1] * 255 ), math.Round( bgcolor[2] * 255 ), math.Round( bgcolor[3] * 255 )
		else
			timer.Simple( 0.1, function() RunConsoleCommand( "cl_playercolor", "0.24 0.34 0.41" ) end )
		end
	end
	Frame.Paint = function( self, w, h )
		draw.RoundedBox( 10, 0, 0, w, h, Color( r, g, b, 127 ) ) return true
	end
	
	Frame.lblTitle:SetTextColor( Color( 0, 0, 0, 255 ) )
	Frame.lblTitle.Paint = function ( self, w, h )
		draw.SimpleTextOutlined( Frame.lblTitle:GetText(), "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255), 0, 0, 1, Color( 0, 0, 0, 255) ) return true
	end
	
	Frame.btnMinim:SetVisible( false )
	Frame.btnMaxim.Paint = function( panel, w, h ) derma.SkinHook( "Paint", "WindowMinimizeButton", panel, w, h ) end
	Frame.btnMaxim:SetEnabled( true )
	Frame.btnMaxim.DoClick = function()
		Frame:SetVisible( false )
	end

	local mdl = Frame:Add( "DModelPanel" )
	mdl:Dock( LEFT )
	mdl:SetSize( 520, 0 )
	mdl:SetFOV( 36 )
	mdl:SetCamPos( Vector( 0, 0, 0 ) )
	mdl:SetDirectionalLight( BOX_RIGHT, Color( 255, 160, 80, 255 ) )
	mdl:SetDirectionalLight( BOX_LEFT, Color( 80, 160, 255, 255 ) )
	mdl:SetAmbientLight( Vector( -64, -64, -64 ) )
	mdl:SetAnimated( true )
	mdl.Angles = Angle( 0, 0, 0 )
	mdl:SetLookAt( Vector( -100, 0, -22 ) )

	local b = Frame:Add( "DButton" )
	b:SetSize( 30, 18 )
	b:SetPos( 860, 3 )
	b:SetText( "Info" )
	b.DoClick = function()
		gui.OpenURL( "http://steamcommunity.com/sharedfiles/filedetails/?id=504945881" )
	end
	
	local topmenu = Frame:Add( "DPanel" )
	topmenu:SetPaintBackground( false )
	topmenu:Dock( TOP )
	topmenu:SetSize( 0, 40 )
	
	local b = topmenu:Add( "DButton" )
	b:SetSize( 200, 30 )
	b:SetPos( 0, 0 )
	b:SetText( "Apply selected playermodel" )
	b:SetEnabled( LocalPlayer():IsAdmin() or GetConVar( "sv_playermodel_selector_instantly" ):GetBool() )
	b.DoClick = function()
		if LocalPlayer():IsAdmin() or GetConVar( "sv_playermodel_selector_instantly" ):GetBool() then
			net.Start("lf_playermodel_update")
			net.SendToServer()
		end
	end
	
	local c = topmenu:Add( "DCheckBoxLabel" )
	c.cvar = "cl_playermodel_selector_force"
	c:SetPos( 250, 8 )
	c:SetValue( GetConVar(c.cvar):GetBool() )
	c:SetText( "Enforce your playermodel" )
	c:SetTooltip( "If enabled, your selected playermodel will\nbe protected. No other function will be\nable to change your playermodel anymore." )
	c:SizeToContents()
	c.Label.Paint = function ( self, w, h )
		draw.SimpleTextOutlined( c.Label:GetText(), "DermaDefault", 0, 0, Color( 255, 255, 255, 255), 0, 0, 1, Color( 0, 0, 0, 255) ) return true
	end
	c.OnChange = function( p, v )
		RunConsoleCommand( c.cvar, v == true and "1" or "0" )
	end
	
	
	local sheet = Frame:Add( "DPropertySheet" )
	sheet:Dock( RIGHT )
	sheet:SetSize( 430, 0 )
		
		
		local PanelSelect = sheet:Add( "DPanelSelect" )
		sheet:AddSheet( "Model", PanelSelect, "icon16/user.png" )
		
		local models = player_manager.AllValidModels()
		local rmodelscvar = GetConVar( "sv_playermodel_selector_blacklist" ):GetString()
		
		if #restricted_models>0 then
			table.Empty( restricted_models )
		end
		
		if rmodelscvar!="" then
			
			local restricted_models_list = string.Explode( ",", rmodelscvar )
			
			for _, name in pairs(restricted_models_list) do
				restricted_models[name] = true
			end
			
		end

		for name, model in SortedPairs( models ) do
			
			if !restricted_models[name] then
				
				local icon = vgui.Create( "SpawnIcon" )
				icon:SetModel( model )
				icon:SetSize( 64, 64 )
				icon:SetTooltip( name )
				icon.playermodel = name

				PanelSelect:AddPanel( icon, { cl_playermodel = name } )
				
			end

		end
		
		
		local favorites = sheet:Add( "DPanel" )
		sheet:AddSheet( "Favorites", favorites, "icon16/star.png" )
		favorites:DockPadding( 8, 8, 8, 8 )
		
		local t = favorites:Add( "DLabel" )
		t:Dock( TOP )
		t:SetSize( 0, 65 )
		t:SetText( "Here you can save your favorite playermodel combinations. To do this:\n1. Select a model in the Model tab.\n2. Setup the skin and bodygroups as you wish.\n3. Enter a unique name into the textfield and click Add new favorite." )
		t:SetDark( true )
		t:SetWrap( true )
		
		local control = favorites:Add( "DPanel" )
		control:Dock( TOP )
		control:SetSize( 0, 70 )
		control:SetPaintBackground( false )
		
		local FavList = favorites:Add( "DListView" )
		FavList:Dock( FILL )
		FavList:SetMultiSelect( true )
		FavList:AddColumn( "Favorites" )
		FavList:AddColumn( "Model" )
		FavList:AddColumn( "Skin" ):SetFixedWidth( 25 )
		FavList:AddColumn( "Bodygroups" )
		
		function Menu.FavPopulate()
			FavList:Clear()
			for k, v in pairs( Favorites ) do
				FavList:AddLine( k, v.model, v.skin, v.bodygroups )
			end
			FavList:SortByColumn( 1 )
		end
		Menu.FavPopulate()
		
		function Menu.FavAdd( name )
			Favorites[name] = { }
			Favorites[name].model = LocalPlayer():GetInfo( "cl_playermodel" )
			Favorites[name].skin = LocalPlayer():GetInfoNum( "cl_playerskin", 0 )
			Favorites[name].bodygroups = LocalPlayer():GetInfo( "cl_playerbodygroups" )
			file.Write( "playermodel_selector_favorites.txt", util.TableToJSON( Favorites, true ) )
			Menu.FavPopulate()
		end
		
		local FavEntry = control:Add( "DTextEntry" )
		FavEntry:SetPos( 0, 0 )
		FavEntry:SetSize( 260, 20 )
		
		local b = control:Add( "DButton" )
		b:SetPos( 270, 0 )
		b:SetSize( 125, 20 )
		b:SetText( "Add new favorite" )
		b.DoClick = function()
			local name = FavEntry:GetValue()
			if name == "" then return end
			Menu.FavAdd( name )
		end
		
		local b = control:Add( "DButton" )
		b:SetPos( 270, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Overwrite selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			Menu.FavAdd( name )
		end
		
		local b = control:Add( "DButton" )
		b:SetPos( 135, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Delete all selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			for k, v in pairs( sel ) do
				local name = tostring( v:GetValue(1) )
				Favorites[name] = nil
			end
			file.Write( "playermodel_selector_favorites.txt", util.TableToJSON( Favorites ) )
			Menu.FavPopulate()
		end
		
		local b = control:Add( "DButton" )
		b:SetPos( 0, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Load selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			if istable( Favorites[name] ) then
				if restricted_models[Favorites[name].model] then return end
				RunConsoleCommand( "cl_playermodel", Favorites[name].model )
				timer.Simple( 0.1, function()
					PanelSelect:FindBestActive()
					RunConsoleCommand( "cl_playerbodygroups", Favorites[name].bodygroups )
					RunConsoleCommand( "cl_playerskin", Favorites[name].skin )
				end )
			end
		end
		
		
		local bdcontrols = Frame:Add( "DPanel" )
		local bgtab = sheet:AddSheet( "Bodygroups", bdcontrols, "icon16/cog.png" )
		bdcontrols:DockPadding( 8, 8, 8, 8 )

		local bdcontrolspanel = bdcontrols:Add( "DPanelList" )
		bdcontrolspanel:EnableVerticalScrollbar( true )
		bdcontrolspanel:Dock( FILL )
		
		
		local flexcontrols = Frame:Add( "DPanel" )
		local flextab = sheet:AddSheet( "Flexes", flexcontrols, "icon16/emoticon_wink.png" )
		flexcontrols:DockPadding( 8, 8, 8, 8 )
		
		local flexcontrolspanel = flexcontrols:Add( "DPanelList" )
		flexcontrolspanel:EnableVerticalScrollbar( true )
		flexcontrolspanel:Dock( FILL )
		
		
		local controls = Frame:Add( "DPanel" )
		sheet:AddSheet( "Colors", controls, "icon16/color_wheel.png" )
		controls:DockPadding( 8, 8, 8, 8 )

		local lbl = controls:Add( "DLabel" )
		lbl:SetText( "Player color" )
		lbl:SetTextColor( Color( 0, 0, 0, 255 ) )
		lbl:Dock( TOP )

		local plycol = controls:Add( "DColorMixer" )
		plycol:SetAlphaBar( false )
		plycol:SetPalette( false )
		plycol:Dock( TOP )
		plycol:SetSize( 200, 250 )

		local lbl = controls:Add( "DLabel" )
		lbl:SetText( "Physgun color" )
		lbl:SetTextColor( Color( 0, 0, 0, 255 ) )
		lbl:DockMargin( 0, 8, 0, 0 )
		lbl:Dock( TOP )

		local wepcol = controls:Add( "DColorMixer" )
		wepcol:SetAlphaBar( false )
		wepcol:SetPalette( false )
		wepcol:Dock( TOP )
		wepcol:SetSize( 200, 250 )
		wepcol:SetVector( Vector( GetConVar( "cl_weaponcolor" ):GetString() ) )
		
		local b = controls:Add( "DButton" )
		b:DockMargin( 0, 8, 0, 0 )
		b:Dock( LEFT )
		b:SetSize( 200, 20 )
		b:SetText( "Reset to default values" )
		b.DoClick = function()
			plycol:SetVector( Vector( 0.24, 0.34, 0.41 ) )
			wepcol:SetVector( Vector( 0.30, 1.80, 2.10 ) )
			RunConsoleCommand( "cl_playercolor", "0.24 0.34 0.41" )
			RunConsoleCommand( "cl_weaponcolor", "0.30 1.80 2.10" )
		end
		
		local c = controls:Add( "DCheckBoxLabel" )
		c.cvar = "cl_playermodel_selector_bgcolor_custom"
		c:DockMargin( 0, 9, 0, 0 )
		c:Dock( RIGHT )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Use Player color as background" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = function( p, v )
			RunConsoleCommand( c.cvar, v == true and "1" or "0" )
		end
		
		
		if LocalPlayer():IsAdmin() then
			
			local panel = sheet:Add( "DPanel" )
			sheet:AddSheet( "Admin", panel, "icon16/key.png" )
			panel:DockPadding( 10, 10, 10, 10 )
			
			local function ChangeCVar( p, v )
				net.Start("lf_playermodel_cvar_change")
				net.WriteString( p.cvar )
				net.WriteString( v == true and "1" or "0" )
				net.SendToServer()
			end
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_force"
			c:Dock( TOP )
			c:DockMargin( 0, 0, 0, 5 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Enable playermodel enforcement" )
			c:SetDark( true )
			c.OnChange = ChangeCVar
			
			local t = panel:Add( "DLabel" )
			t:Dock( TOP )
			t:DockMargin( 0, 0, 0, 20 )
			t:SetAutoStretchVertical( true )
			t:SetText( "If enabled, selected playermodels will be enforced and protected. No gamemodes, maps or addons can overwrite them anymore. Players can toggle this function individually, using the checkbox on top of the menu.\nIf disabled, only the manual button works outside of Sandbox." )
			t:SetDark( true )
			t:SetWrap( true )
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_instantly"
			c:Dock( TOP )
			c:DockMargin( 0, 0, 0, 5 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow instant changes" )
			c:SetDark( true )
			c.OnChange = ChangeCVar
			
			local t = panel:Add( "DLabel" )
			t:Dock( TOP )
			t:DockMargin( 0, 0, 0, 20 )
			t:SetAutoStretchVertical( true )
			t:SetText( "If enabled, players can apply their changes instantly instead of having to respawn." )
			t:SetDark( true )
			t:SetWrap( true )
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_flexes"
			c:Dock( TOP )
			c:DockMargin( 0, 0, 0, 5 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow players to change flexes" )
			c:SetDark( true )
			c.OnChange = ChangeCVar
			
			local t = panel:Add( "DLabel" )
			t:Dock( TOP )
			t:DockMargin( 0, 0, 0, 20 )
			t:SetAutoStretchVertical( true )
			t:SetText( "If enabled, players can change the flexes for their playermodels. This will break player blinking and may cause other issues. Enable at own risk. Players can only reset their flexes by disconnecting." )
			t:SetDark( true )
			t:SetWrap( true )
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_gamemodes"
			c:Dock( TOP )
			c:DockMargin( 0, 0, 0, 5 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Enable in all gamemodes" )
			c:SetDark( true )
			c.OnChange = ChangeCVar
			
			local t = panel:Add( "DLabel" )
			t:Dock( TOP )
			t:DockMargin( 0, 0, 0, 20 )
			t:SetAutoStretchVertical( true )
			t:SetText( "If enabled, the PlayerModel Selector will be available for all players in every gamemode. If disabled, only Admins can use it outside of Sandbox." )
			t:SetDark( true )
			t:SetWrap( true )
			
			local panel2 = panel:Add( "DPanel" )
			panel2:Dock( FILL )
			panel2:SetPaintBackground( false )
			
			local Blacklist = panel2:Add( "DListView" )
			Blacklist:Dock( LEFT )
			Blacklist:DockMargin( 0, 0, 20, 0 )
			Blacklist:SetWidth( 150 )
			Blacklist:SetMultiSelect( true )
			Blacklist:AddColumn( "Blacklisted gamemodes" )
			
			net.Receive("lf_playermodel_blacklist", function()
				local tbl = net.ReadTable()
				Blacklist:Clear()
				for k, v in pairs( tbl ) do
					Blacklist:AddLine( k )
					Blacklist:SortByColumn( 1 )
				end
			end )
			
			function Menu.BlacklistPopulate()
				net.Start( "lf_playermodel_blacklist" )
				net.WriteInt( 0, 3 )
				net.SendToServer()
			end
			Menu.BlacklistPopulate()
			
			local t = panel2:Add( "DLabel" )
			t:Dock( TOP )
			t:DockMargin( 0, 0, 0, 20 )
			t:SetAutoStretchVertical( true )
			t:SetText( "Here you can blacklist incompatible gamemodes.\n\nPlayers (including Admins) can't change their playermodels in those gamemodes, regardless of other settings." )
			t:SetDark( true )
			t:SetWrap( true )
			
			local b = panel2:Add( "DButton" )
			b:Dock( TOP )
			b:DockMargin( 0, 0, 0, 20 )
			b:SetHeight( 25 )
			b:SetText( "Add current gamemode to Blacklist" )
			b.DoClick = function()
				if GAMEMODE_NAME == "sandbox" then return end
				net.Start( "lf_playermodel_blacklist" )
				net.WriteInt( 1, 3 )
				net.WriteString( GAMEMODE_NAME )
				net.SendToServer()
			end
			
			local TextEntry = panel2:Add( "DTextEntry" )
			TextEntry:Dock( TOP )
			TextEntry:DockMargin( 0, 0, 0, 10 )
			TextEntry:SetHeight( 20 )
			
			local b = panel2:Add( "DButton" )
			b:Dock( TOP )
			b:DockMargin( 0, 0, 0, 20 )
			b:SetHeight( 20 )
			b:SetText( "Manually add gamemode" )
			b.DoClick = function()
				local name = TextEntry:GetValue()
				if name == "" or name == "sandbox" then return end
				net.Start( "lf_playermodel_blacklist" )
				net.WriteInt( 1, 3 )
				net.WriteString( name )
				net.SendToServer()
			end
			
			local b = panel2:Add( "DButton" )
			b:Dock( TOP )
			b:DockMargin( 0, 0, 0, 0 )
			b:SetHeight( 25 )
			b:SetText( "Remove all selected gamemodes" )
			b.DoClick = function()
				local tbl = { }
				local sel = Blacklist:GetSelected()
				for k, v in pairs( sel ) do
					local name = tostring( v:GetValue(1) )
					table.insert( tbl, name )
				end
				net.Start( "lf_playermodel_blacklist" )
				net.WriteInt( 2, 3 )
				net.WriteTable( tbl )
				net.SendToServer()
			end
			
		end


	-- Helper functions

	function Menu.MakeNiceName( str )
		local newname = {}

		for _, s in pairs( string.Explode( "_", str ) ) do
			if ( string.len( s ) == 1 ) then table.insert( newname, string.upper( s ) ) continue end
			table.insert( newname, string.upper( string.Left( s, 1 ) ) .. string.Right( s, string.len( s ) - 1 ) ) -- Ugly way to capitalize first letters.
		end

		return string.Implode( " ", newname )
	end

	function Menu.PlayPreviewAnimation( panel, playermodel )

		if ( !panel or !IsValid( panel.Entity ) ) then return end

		local anims = list.Get( "PlayerOptionsAnimations" )

		local anim = default_animations[ math.random( 1, #default_animations ) ]
		if ( anims[ playermodel ] ) then
			anims = anims[ playermodel ]
			anim = anims[ math.random( 1, #anims ) ]
		end

		local iSeq = panel.Entity:LookupSequence( anim )
		if ( iSeq > 0 ) then panel.Entity:ResetSequence( iSeq ) end

	end

	-- Updating

	function Menu.UpdateBodyGroups( pnl, val )
		if ( pnl.type == "bgroup" ) then

			mdl.Entity:SetBodygroup( pnl.typenum, math.Round( val ) )

			local str = string.Explode( " ", GetConVar( "cl_playerbodygroups" ):GetString() )
			if ( #str < pnl.typenum + 1 ) then for i = 1, pnl.typenum + 1 do str[ i ] = str[ i ] or 0 end end
			str[ pnl.typenum + 1 ] = math.Round( val )
			RunConsoleCommand( "cl_playerbodygroups", table.concat( str, " " ) )
		
		elseif ( pnl.type == "flex" ) then

			mdl.Entity:SetFlexWeight( pnl.typenum, math.Round( val, 2 ) )

			local str = string.Explode( " ", GetConVar( "cl_playerflexes" ):GetString() )
			if ( #str < pnl.typenum + 1 ) then for i = 1, pnl.typenum + 1 do str[ i ] = str[ i ] or 0 end end
			str[ pnl.typenum + 1 ] = math.Round( val, 2 )
			RunConsoleCommand( "cl_playerflexes", table.concat( str, " " ) )
		
		elseif ( pnl.type == "skin" ) then

			mdl.Entity:SetSkin( math.Round( val ) )
			RunConsoleCommand( "cl_playerskin", math.Round( val ) )

		end
	end

	function Menu.RebuildBodygroupTab()
		bdcontrolspanel:Clear()
		flexcontrolspanel:Clear()
		
		bgtab.Tab:SetVisible( false )
		flextab.Tab:SetVisible( false )

		local nskins = mdl.Entity:SkinCount() - 1
		if ( nskins > 0 ) then
			local skins = vgui.Create( "DNumSlider" )
			skins:Dock( TOP )
			skins:SetText( "Skin" )
			skins:SetDark( true )
			skins:SetTall( 50 )
			skins:SetDecimals( 0 )
			skins:SetMax( nskins )
			skins:SetValue( GetConVar( "cl_playerskin" ):GetInt() )
			skins.type = "skin"
			skins.OnValueChanged = Menu.UpdateBodyGroups
			
			bdcontrolspanel:AddItem( skins )

			mdl.Entity:SetSkin( GetConVar( "cl_playerskin" ):GetInt() )
			
			bgtab.Tab:SetVisible( true )
		end

		local groups = string.Explode( " ", GetConVar( "cl_playerbodygroups" ):GetString() )
		for k = 0, mdl.Entity:GetNumBodyGroups() - 1 do
			if ( mdl.Entity:GetBodygroupCount( k ) <= 1 ) then continue end

			local bgroup = vgui.Create( "DNumSlider" )
			bgroup:Dock( TOP )
			bgroup:SetText( Menu.MakeNiceName( mdl.Entity:GetBodygroupName( k ) ) )
			bgroup:SetDark( true )
			bgroup:SetTall( 50 )
			bgroup:SetDecimals( 0 )
			bgroup.type = "bgroup"
			bgroup.typenum = k
			bgroup:SetMax( mdl.Entity:GetBodygroupCount( k ) - 1 )
			bgroup:SetValue( groups[ k + 1 ] or 0 )
			bgroup.OnValueChanged = Menu.UpdateBodyGroups
			
			bdcontrolspanel:AddItem( bgroup )

			mdl.Entity:SetBodygroup( k, groups[ k + 1 ] or 0 )
			
			bgtab.Tab:SetVisible( true )
		end
		
		if GetConVar( "sv_playermodel_selector_flexes" ):GetBool() then
			if flexes_unlocked or GetConVar( "cl_playermodel_selector_unlockflexes" ):GetBool() then
				flexes_unlocked = true
				
				local t = vgui.Create( "DLabel" )
				t:Dock( TOP )
				t:SetTall( 70 )
				t:SetText( "Notes:\n-The model preview for flexes doesn't work correctly. However, they will be visible on your playermodel when you apply them.\n- The default values provided might not be correct and cause distorted faces.\n- There is no way to reset (or fix) flex manipulation besides disconnecting." )
				t:SetDark( true )
				t:SetWrap( true )
				flexcontrolspanel:AddItem( t )
				
				local flexes = string.Explode( " ", GetConVar( "cl_playerflexes" ):GetString() )
				for k = 0, mdl.Entity:GetFlexNum() - 1 do
					if ( mdl.Entity:GetFlexNum( k ) <= 1 ) then continue end

					local flex = vgui.Create( "DNumSlider" )
					local vmin, vmax = mdl.Entity:GetFlexBounds( k )
					local default = 0
					if vmin == -1 and vmax == 1 then default = 0.5 end
					flex:Dock( TOP )
					flex:SetText( Menu.MakeNiceName( mdl.Entity:GetFlexName( k ) ) )
					flex:SetDark( true )
					flex:SetTall( 30 )
					flex:SetDecimals( 2 )
					flex.type = "flex"
					flex.typenum = k
					flex:SetMin( vmin )
					flex:SetMax( vmax )
					flex:SetValue( flexes[ k + 1 ] or default )
					flex.OnValueChanged = Menu.UpdateBodyGroups
					
					flexcontrolspanel:AddItem( flex )

					mdl.Entity:SetFlexWeight( k, flexes[ k + 1 ] or default )
					
					flextab.Tab:SetVisible( true )
				end
			else
				local t = vgui.Create( "DLabel" )
				t:Dock( TOP )
				t:SetTall( 40 )
				t:SetText( "Read before using!" )
				t:SetFont( "DermaLarge" )
				t:SetTextColor( Color( 255, 0, 0, 255 ) )
				t:SetWrap( true )
				flexcontrolspanel:AddItem( t )
				
				local t = vgui.Create( "DLabel" )
				t:Dock( TOP )
				t:SetTall( 120 )
				t:SetText( "Here you can manipulate flexes on your playermodel. However, flex manipulation is not really made for playermodels and will cause issues. This includes the following:\n- Eye blinking no longer working.\n- Faces might be distorted unless the flexes are corrected manually.\n- Might break the faces of incompatible playermodels completely.\n- Even if you put all flexes to default value, the engine still considers them as manipulated. Models with problems won't be fixed." )
				t:SetDark( true )
				t:SetWrap( true )
				flexcontrolspanel:AddItem( t )
				
				local t = vgui.Create( "DLabel" )
				t:Dock( TOP )
				t:SetTall( 40 )
				t:SetText( "Unlocking flex manipulation can only be undone by DISCONNECTING, a simple respawn or model change won't fix these issues." )
				t:SetTextColor( Color( 255, 0, 0, 255 ) )
				t:SetWrap( true )
				flexcontrolspanel:AddItem( t )
				
				local b = vgui.Create( "DButton" )
				b:Dock( TOP )
				b:DockPadding( 100, 100, 20, 20 )
				b:SetTall( 30 )
				b:SetText( "Unlock flex manipulation (can not be undone)" )
				b.DoClick = function()
					RunConsoleCommand( "cl_playermodel_selector_unlockflexes", "1" )
					flexes_unlocked = true
					Menu.RebuildBodygroupTab()
				end
				flexcontrolspanel:AddItem( b )
				
				flextab.Tab:SetVisible( true )
			end
		end
	end
	
	function Menu.UpdateFromConvars()

		local model = LocalPlayer():GetInfo( "cl_playermodel" )
		local modelname = player_manager.TranslatePlayerModel( model )
		util.PrecacheModel( modelname )
		mdl:SetModel( modelname )
		mdl.Entity.GetPlayerColor = function() return Vector( GetConVar( "cl_playercolor" ):GetString() ) end
		mdl.Entity:SetPos( Vector( -100, 0, -61 ) )

		plycol:SetVector( Vector( GetConVar( "cl_playercolor" ):GetString() ) )
		wepcol:SetVector( Vector( GetConVar( "cl_weaponcolor" ):GetString() ) )

		Menu.PlayPreviewAnimation( mdl, model )
		Menu.RebuildBodygroupTab()

	end

	function Menu.UpdateFromControls()

		RunConsoleCommand( "cl_playercolor", tostring( plycol:GetVector() ) )
		RunConsoleCommand( "cl_weaponcolor", tostring( wepcol:GetVector() ) )

	end

	plycol.ValueChanged = Menu.UpdateFromControls
	wepcol.ValueChanged = Menu.UpdateFromControls

	Menu.UpdateFromConvars()

	function PanelSelect:OnActivePanelChanged( old, new )

		if ( old != new ) then -- Only reset if we changed the model
			RunConsoleCommand( "cl_playerbodygroups", "0" )
			RunConsoleCommand( "cl_playerskin", "0" )
			RunConsoleCommand( "cl_playerflexes", "0" )
		end

		timer.Simple( 0.1, function() Menu.UpdateFromConvars() end )

	end

	-- Hold to rotate

	function mdl:DragMousePress()
		self.PressX, self.PressY = gui.MousePos()
		self.Pressed = true
	end

	function mdl:DragMouseRelease() self.Pressed = false end

	function mdl:LayoutEntity( Entity )
		if ( self.bAnimated ) then self:RunAnimation() end

		if ( self.Pressed ) then
			local mx, my = gui.MousePos()
			self.Angles = self.Angles - Angle( 0, ( self.PressX or mx ) - mx, 0 )
			
			self.PressX, self.PressY = gui.MousePos()
		end

		Entity:SetAngles( self.Angles )
	end

end

function Menu.Toggle()
	if LocalPlayer():IsAdmin() or GAMEMODE_NAME == "sandbox" or GetConVar( "sv_playermodel_selector_gamemodes" ):GetBool()
	then
		if IsValid( Frame ) then
			Frame:ToggleVisible()
		else
			Menu.Setup()
		end
	else
		if IsValid( Frame ) then Frame:Close() end
	end
end

concommand.Add( "playermodel_selector", Menu.Toggle )


hook.Add( "Initialize", "lf_playermodel_desktop_hook", function()
		list.Set( "DesktopWindows", "PlayerEditor", {
			title		= "Player Model",
			icon		= "icon64/playermodel.png",
			init		= function( icon, window )
				window:Remove()
				RunConsoleCommand("playermodel_selector")
			end
		} )
end )



list.Set( "PlayerOptionsAnimations", "gman", { "menu_gman" } )

list.Set( "PlayerOptionsAnimations", "hostage01", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage02", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage03", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage04", { "idle_all_scared" } )

list.Set( "PlayerOptionsAnimations", "zombine", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "corpse", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombiefast", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombie", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "skeleton", { "menu_zombie_01" } )

list.Set( "PlayerOptionsAnimations", "combine", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineprison", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineelite", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "police", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "policefem", { "menu_combine" } )

list.Set( "PlayerOptionsAnimations", "css_arctic", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_gasmask", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_guerilla", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_leet", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_phoenix", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_riot", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_swat", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_urban", { "pose_standing_02", "idle_fist" } )

local bonus = { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all", "idle_all_scared", "idle_magic" }
list.Set( "PlayerOptionsAnimations", "May", bonus )
list.Set( "PlayerOptionsAnimations", "Dawn", bonus )
list.Set( "PlayerOptionsAnimations", "Rosa", bonus )
list.Set( "PlayerOptionsAnimations", "Hilda", bonus )
list.Set( "PlayerOptionsAnimations", "Mami", bonus )
list.Set( "PlayerOptionsAnimations", "Tda Hatsune Miku (v2)", bonus )


end