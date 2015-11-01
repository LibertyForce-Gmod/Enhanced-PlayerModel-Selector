-- Enhanced PlayerModel Selector
-- Upgraded code by LibertyForce http://steamcommunity.com/id/libertyforce
-- Based on: https://github.com/garrynewman/garrysmod/blob/1a2c317eeeef691e923453018236cf9f66ee74b4/garrysmod/gamemodes/sandbox/gamemode/editor_player.lua


if SERVER then


AddCSLuaFile()

local convars = { }
convars["sv_playermodel_selector_enabled"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_gamemodes"]	= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_instantly"]	= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_flexes"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["sv_playermodel_selector_delay"]		= { 100, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }

for cvar, v in pairs( convars ) do
	CreateConVar( cvar,	v[1], v[2] )
end

util.AddNetworkString("lf_playermodel_cvar_sync")
hook.Add( "PlayerAuthed", "lf_playermodel_cvar_sync_hook", function( ply )
	local tbl = { }
	for cvar in pairs( convars ) do
		tbl[cvar] = GetConVar(cvar):GetInt()
	end
	net.Start("lf_playermodel_cvar_sync")
	net.WriteTable( tbl )
	net.Send( ply )
end )

util.AddNetworkString("lf_playermodel_cvar_change")
net.Receive("lf_playermodel_cvar_change", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local cvar = net.ReadString()
		if !convars[cvar] then ply:Kick("Illegal convar change") return end
		if !ply:IsAdmin() then return end
		RunConsoleCommand( cvar, net.ReadString() )
	end
end)


local legs_installed = false
if file.Exists( "autorun/sh_legs.lua", "LUA" ) then legs_installed = true end


local function UpdatePlayerModel( ply )
	if ply:IsAdmin() or
	( GetConVar( "sv_playermodel_selector_enabled"):GetBool() and ( GAMEMODE_NAME == "sandbox" or GetConVar( "sv_playermodel_selector_gamemodes"):GetBool() ) )
	then
	
		local mdlname = ply:GetInfo( "cl_playermodel" )
		local mdlpath = player_manager.TranslatePlayerModel( mdlname )
		
		ply:SetModel( mdlpath )
		
		local skin = ply:GetInfoNum( "cl_playerskin", 0 )
		ply:SetSkin( skin )
		
		local groups = ply:GetInfo( "cl_playerbodygroups" )
		if ( groups == nil ) then groups = "" end
		local groups = string.Explode( " ", groups )
		for k = 0, ply:GetNumBodyGroups() - 1 do
			ply:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
		end
		
		if GetConVar( "sv_playermodel_selector_flexes" ):GetBool() then
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
		
		ply:SetupHands( )
		
		if legs_installed then
			ply:SetNWString( "realModel", mdlpath )
			timer.Simple( 0.1, function()
				net.Start("lf_playermodel_update")
				net.Send( ply )
			end )
		end
		
	end
end

util.AddNetworkString("lf_playermodel_update")
net.Receive("lf_playermodel_update", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		UpdatePlayerModel( ply )
	end
end)

hook.Add( "PlayerSpawn", "lf_playermodel_force_hook", function( ply )
	if GetConVar( "sv_playermodel_selector_gamemodes"):GetBool() and tobool( ply:GetInfoNum( "cl_playermodel_force", 0 ) ) then
		local delay = GetConVar( "sv_playermodel_selector_delay" ):GetInt()
		if delay > 2000 then delay = 2000
		elseif delay < 10 then delay = 10
		end
		timer.Simple( delay / 1000, function()
			UpdatePlayerModel( ply )
		end)
	end
end)


end

-----------------------------------------------------------------------------------------------------------------------------------------------------

if CLIENT then


local Frame
local default_animations = { "idle_all_01", "menu_walk" }
local Favorites = { }

if file.Exists( "playermodel_selector_favorites.txt", "DATA" ) then
	Favorites = util.JSONToTable( file.Read( "playermodel_selector_favorites.txt", "DATA" ) )
	if !istable( Favorites ) then Favorites = { } end
end


CreateClientConVar( "cl_playermodel_force", "1", true, true )

net.Receive("lf_playermodel_cvar_sync", function()
	local tbl = net.ReadTable()
	for k,v in pairs( tbl ) do
		CreateConVar( k, v, { FCVAR_REPLICATED } )
	end
end)

hook.Add( "PostGamemodeLoaded", "lf_playermodel_sboxcvars", function()
	if !ConVarExists( "cl_playercolor" ) then CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" ) end
	if !ConVarExists( "cl_weaponcolor" ) then CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" ) end
	if !ConVarExists( "cl_playerskin" ) then CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" ) end
	if !ConVarExists( "cl_playerbodygroups" ) then CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" ) end
	if !ConVarExists( "cl_playerflexes" ) then CreateConVar( "cl_playerflexes", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The flexes to use, if the model has any" ) end
end )


net.Receive("lf_playermodel_update", function()
		include( "autorun/sh_legs.lua" )
end)

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


local function Menu()

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
	
	Frame.btnMinim:SetEnabled( true )
	Frame.btnMinim.DoClick = function()
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

	local topmenu = Frame:Add( "DPanel" )
	topmenu:SetPaintBackground( false )
	topmenu:Dock( TOP )
	topmenu:SetSize( 0, 40 )
	
	local b = topmenu:Add( "DButton" )
	b:SetSize( 200, 30 )
	b:SetPos( 0, 0 )
	b:SetText( "Apply selected Playermodel" )
	b:SetEnabled( LocalPlayer():IsAdmin() or GetConVar( "sv_playermodel_selector_instantly" ):GetBool() )
	b.DoClick = function()
		if LocalPlayer():IsAdmin() or GetConVar( "sv_playermodel_selector_instantly" ):GetBool() then
			net.Start("lf_playermodel_update")
			net.SendToServer()
		end
	end
	
	local c = topmenu:Add( "DCheckBoxLabel" )
	c.cvar = "cl_playermodel_force"
	c:SetPos( 250, 8 )
	c:SetValue( GetConVar(c.cvar):GetBool() )
	c:SetText( "Force playermodel on spawn" )
	c:SetTooltip( "If enabled, the selected playermodel will be applied upon spawn in every gamemode." )
	c:SizeToContents()
	c.OnChange = function( p, v )
		RunConsoleCommand( c.cvar, v == true and "1" or "0" )
	end
	
	
	local sheet = Frame:Add( "DPropertySheet" )
	sheet:Dock( RIGHT )
	sheet:SetSize( 430, 0 )
		
		
		local PanelSelect = sheet:Add( "DPanelSelect" )
		sheet:AddSheet( "Model", PanelSelect, "icon16/user.png" )

		for name, model in SortedPairs( player_manager.AllValidModels() ) do

			local icon = vgui.Create( "SpawnIcon" )
			icon:SetModel( model )
			icon:SetSize( 64, 64 )
			icon:SetTooltip( name )
			icon.playermodel = name

			PanelSelect:AddPanel( icon, { cl_playermodel = name } )

		end
		
		
		local favorites = sheet:Add( "DPanel" )
		sheet:AddSheet( "Favorites", favorites, "icon16/star.png" )
		favorites:DockPadding( 8, 8, 8, 8 )
		
		local t = favorites:Add( "DLabel", panel )
		t:Dock( TOP )
		t:SetSize( 0, 65 )
		t:SetText( "Here you can save your favorite playermodel combinations. To do this:\n1. Select a model in the Model tab.\n2. Setup the skin, bodygroups and flexes as you wish.\n3. Enter a unique name into the textfield and click Add new favorite." )
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
		
		local function FavPopulate()
			FavList:Clear()
			for k, v in pairs( Favorites ) do
				FavList:AddLine( k, v.model, v.skin, v.bodygroups )
			end
			FavList:SortByColumn( 1 )
		end
		FavPopulate()
		
		local function FavAdd( name )
			Favorites[name] = { }
			Favorites[name].model = LocalPlayer():GetInfo( "cl_playermodel" )
			Favorites[name].skin = LocalPlayer():GetInfoNum( "cl_playerskin", 0 )
			Favorites[name].bodygroups = LocalPlayer():GetInfo( "cl_playerbodygroups" )
			Favorites[name].flexes = LocalPlayer():GetInfo( "cl_playerflexes" )
			file.Write( "playermodel_selector_favorites.txt", util.TableToJSON( Favorites ) )
			FavPopulate()
		end
		
		local FavEntry = control:Add( "DTextEntry" )
		FavEntry:SetPos( 0, 0 )
		FavEntry:SetSize( 260, 20 )
		
		local b = control:Add( "DButton", panel )
		b:SetPos( 270, 0 )
		b:SetSize( 125, 20 )
		b:SetText( "Add new favorite" )
		b.DoClick = function()
			local name = FavEntry:GetValue()
			if name == "" then return end
			FavAdd( name )
		end
		
		local b = control:Add( "DButton", panel )
		b:SetPos( 270, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Overwrite selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			FavAdd( name )
		end
		
		local b = control:Add( "DButton", panel )
		b:SetPos( 135, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Delete all selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			for k,v in pairs( sel ) do
				local name = tostring( v:GetValue(1) )
				Favorites[name] = nil
			end
			file.Write( "playermodel_selector_favorites.txt", util.TableToJSON( Favorites ) )
			FavPopulate()
		end
		
		local b = control:Add( "DButton", panel )
		b:SetPos( 0, 30 )
		b:SetSize( 125, 20 )
		b:SetText( "Load selected" )
		b.DoClick = function()
			local sel = FavList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			if istable( Favorites[name] ) then
				RunConsoleCommand( "cl_playermodel", Favorites[name].model )
				timer.Simple( 0.1, function()
					PanelSelect:FindBestActive()
					RunConsoleCommand( "cl_playerbodygroups", Favorites[name].bodygroups )
					RunConsoleCommand( "cl_playerskin", Favorites[name].skin )
					RunConsoleCommand( "cl_playerflexes", Favorites[name].flexes )
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

		local t = flexcontrols:Add( "DLabel", panel )
		t:Dock( TOP )
		t:SetSize( 0, 30 )
		t:SetText( "Note: The model preview for flexes doesn't work correcty.\nHowever, they will be visible on your playermodel when you apply them." )
		t:SetDark( true )
		t:SetWrap( true )
		
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
		b:Dock( TOP )
		b:SetSize( 50, 20 )
		b:SetText( "Reset to default values" )
		b.DoClick = function()
			plycol:SetVector( Vector( 0.24, 0.34, 0.41 ) )
			wepcol:SetVector( Vector( 0.30, 1.80, 2.10 ) )
			RunConsoleCommand( "cl_playercolor", "0.24 0.34 0.41" )
			RunConsoleCommand( "cl_weaponcolor", "0.30 1.80 2.10" )
		end
		
		
		if LocalPlayer():IsAdmin() then
			
			local panel = sheet:Add( "DPanel" )
			sheet:AddSheet( "Admin", panel, "icon16/key.png" )
			panel:DockPadding( 8, 8, 8, 8 )
			
			local function ChangeCVar( p, v )
				net.Start("lf_playermodel_cvar_change")
				net.WriteString( p.cvar )
				net.WriteString( v == true and "1" or "0" )
				net.SendToServer()
			end
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_enabled"
			c:SetPos( 10, 20 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Enable menu for all players" )
			c:SetTooltip( "If enabled, the Playermodel Selector can be used by all players. If disabled, only admins can use it." )
			c:SetDark( true )
			c:SizeToContents()
			c.OnChange = ChangeCVar
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_instantly"
			c:SetPos( 10, 50 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow instant changes" )
			c:SetTooltip( "If enabled, players can apply their changes instantly instead of having to respawn." )
			c:SetDark( true )
			c:SizeToContents()
			c.OnChange = ChangeCVar
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_flexes"
			c:SetPos( 10, 80 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow players to change flexes" )
			c:SetTooltip( "If enabled, players can change the flexes for their playermodels." )
			c:SetDark( true )
			c:SizeToContents()
			c.OnChange = ChangeCVar
			
			local c = panel:Add( "DCheckBoxLabel" )
			c.cvar = "sv_playermodel_selector_gamemodes"
			c:SetPos( 10, 110 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow playermodel enforcement" )
			c:SetTooltip( "If enabled, the selected playermodel will be applied upon spawn in every gamemode." )
			c:SetDark( true )
			c:SizeToContents()
			c.OnChange = ChangeCVar
			
			local t = panel:Add( "DLabel" )
			t:SetPos( 10, 140 )
			t:SetSize( 80, 20 )
			t:SetDark( true )
			t:SetText( "Force Delay:" )
			
			local c = panel:Add( "DTextEntry" )
				c:SetPos( 100, 140 )
				c:SetSize( 40, 20 )
				c:SetNumeric( true )
				c:SetValue( GetConVar("sv_playermodel_selector_delay"):GetString() )
				c:SetTooltip( "Delay until your playermodel is enforced. Increase, if it's still overwritten. Decrease, for smoother spawning. Recommended to keep on default, unless you encounter problems." )
				c.OnLoseFocus = function()
					Frame:SetKeyboardInputEnabled( false )
					net.Start("lf_playermodel_cvar_change")
					net.WriteString( "sv_playermodel_selector_delay" )
					net.WriteString( c:GetValue() )
					net.SendToServer()
				end
			
			local t = panel:Add( "DLabel" )
			t:SetPos( 145, 140 )
			t:SetSize( 200, 20 )
			t:SetDark( true )
			t:SetText( "ms    (Min: 10, Max: 2000, Default: 100)" )
			
		end


	-- Helper functions

	local function MakeNiceName( str )
		local newname = {}

		for _, s in pairs( string.Explode( "_", str ) ) do
			if ( string.len( s ) == 1 ) then table.insert( newname, string.upper( s ) ) continue end
			table.insert( newname, string.upper( string.Left( s, 1 ) ) .. string.Right( s, string.len( s ) - 1 ) ) -- Ugly way to capitalize first letters.
		end

		return string.Implode( " ", newname )
	end

	local function PlayPreviewAnimation( panel, playermodel )

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

	local function UpdateBodyGroups( pnl, val )
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

	local function RebuildBodygroupTab()
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
			skins.OnValueChanged = UpdateBodyGroups
			
			bdcontrolspanel:AddItem( skins )

			mdl.Entity:SetSkin( GetConVar( "cl_playerskin" ):GetInt() )
			
			bgtab.Tab:SetVisible( true )
		end

		local groups = string.Explode( " ", GetConVar( "cl_playerbodygroups" ):GetString() )
		for k = 0, mdl.Entity:GetNumBodyGroups() - 1 do
			if ( mdl.Entity:GetBodygroupCount( k ) <= 1 ) then continue end

			local bgroup = vgui.Create( "DNumSlider" )
			bgroup:Dock( TOP )
			bgroup:SetText( MakeNiceName( mdl.Entity:GetBodygroupName( k ) ) )
			bgroup:SetDark( true )
			bgroup:SetTall( 50 )
			bgroup:SetDecimals( 0 )
			bgroup.type = "bgroup"
			bgroup.typenum = k
			bgroup:SetMax( mdl.Entity:GetBodygroupCount( k ) - 1 )
			bgroup:SetValue( groups[ k + 1 ] or 0 )
			bgroup.OnValueChanged = UpdateBodyGroups
			
			bdcontrolspanel:AddItem( bgroup )

			mdl.Entity:SetBodygroup( k, groups[ k + 1 ] or 0 )
			
			bgtab.Tab:SetVisible( true )
		end
		
		if GetConVar( "sv_playermodel_selector_flexes" ):GetBool() then
			local flexes = string.Explode( " ", GetConVar( "cl_playerflexes" ):GetString() )
			for k = 0, mdl.Entity:GetFlexNum() - 1 do
				if ( mdl.Entity:GetFlexNum( k ) <= 1 ) then continue end

				local flex = vgui.Create( "DNumSlider" )
				flex:Dock( TOP )
				flex:SetText( MakeNiceName( mdl.Entity:GetFlexName( k ) ) )
				flex:SetDark( true )
				flex:SetTall( 50 )
				flex:SetDecimals( 2 )
				flex.type = "flex"
				flex.typenum = k
				flex:SetMax( 1 )
				flex:SetValue( flexes[ k + 1 ] or 0 )
				flex.OnValueChanged = UpdateBodyGroups
				
				flexcontrolspanel:AddItem( flex )

				mdl.Entity:SetFlexWeight( k, flexes[ k + 1 ] or 0 )
				
				flextab.Tab:SetVisible( true )
			end
		end
	end
	
	local function UpdateFromConvars()

		local model = LocalPlayer():GetInfo( "cl_playermodel" )
		local modelname = player_manager.TranslatePlayerModel( model )
		util.PrecacheModel( modelname )
		mdl:SetModel( modelname )
		mdl.Entity.GetPlayerColor = function() return Vector( GetConVar( "cl_playercolor" ):GetString() ) end
		mdl.Entity:SetPos( Vector( -100, 0, -61 ) )

		plycol:SetVector( Vector( GetConVar( "cl_playercolor" ):GetString() ) )
		wepcol:SetVector( Vector( GetConVar( "cl_weaponcolor" ):GetString() ) )

		PlayPreviewAnimation( mdl, model )
		RebuildBodygroupTab()

	end

	local function UpdateFromControls()

		RunConsoleCommand( "cl_playercolor", tostring( plycol:GetVector() ) )
		RunConsoleCommand( "cl_weaponcolor", tostring( wepcol:GetVector() ) )

	end

	plycol.ValueChanged = UpdateFromControls
	wepcol.ValueChanged = UpdateFromControls

	UpdateFromConvars()

	function PanelSelect:OnActivePanelChanged( old, new )

		if ( old != new ) then -- Only reset if we changed the model
			RunConsoleCommand( "cl_playerbodygroups", "0" )
			RunConsoleCommand( "cl_playerskin", "0" )
			RunConsoleCommand( "cl_playerflexes", "0" )
		end

		timer.Simple( 0.1, function() UpdateFromConvars() end )

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

local function MenuToggle()
	if LocalPlayer():IsAdmin() or
	( GetConVar( "sv_playermodel_selector_enabled"):GetBool() and ( GAMEMODE_NAME == "sandbox" or GetConVar( "sv_playermodel_selector_gamemodes"):GetBool() ) )
	then
		if IsValid( Frame ) then
			Frame:ToggleVisible()
		else
			Menu()
		end
	else
		if IsValid( Frame ) then Frame:Close() end
	end
end

concommand.Add( "playermodel_selector", MenuToggle )


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

list.Set( "PlayerOptionsAnimations", "May", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )
list.Set( "PlayerOptionsAnimations", "Dawn", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )
list.Set( "PlayerOptionsAnimations", "Rosa", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )
list.Set( "PlayerOptionsAnimations", "Hilda", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )
list.Set( "PlayerOptionsAnimations", "Mami", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )
list.Set( "PlayerOptionsAnimations", "Tda Hatsune Miku (v2)", { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "swim_idle_all" } )


end