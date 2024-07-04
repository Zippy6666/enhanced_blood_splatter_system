if CLIENT then
    function MissingConvMsg()
        local frame = vgui.Create("DFrame")
        frame:SetSize(300, 125)
        frame:SetTitle("Missing Library!")
        frame:Center()
        frame:MakePopup()

        local text = vgui.Create("DLabel", frame)
        text:SetText("This server does not have the CONV library installed, some addons may function incorrectly. Click the link below to get it:")
        text:Dock(TOP)
        text:SetWrap(true)  -- Enable text wrapping for long messages
        text:SetAutoStretchVertical(true)  -- Allow the text label to stretch vertically
        text:SetFont("BudgetLabel")

        local label = vgui.Create("DLabelURL", frame)
        label:SetText("CONV Library")
        label:SetURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3146473253")
        label:Dock(BOTTOM)
        label:SetContentAlignment(5)  -- 5 corresponds to center alignment
    end
elseif SERVER && !file.Exists("convenience/adam.lua", "LUA") then
    -- Conv lib not on on server, send message to clients
    hook.Add("PlayerInitialSpawn", "convenienceerrormsg", function( ply )
        local sendstr = 'MissingConvMsg()'
        ply:SendLua(sendstr)
    end)
end


--]]===========================================================================================]]


AddCSLuaFile("dynsplatter/sh_override_funcs.lua")


game.AddParticles("particles/blood_impact.pcf")
PrecacheParticleSystem("blood_impact_synth_01")

CreateConVar("dynamic_blood_splatter_enable", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))


--]]===========================================================================================]]
hook.Add("InitPostEntity", "DynSplatterOverrideFuncs", function() timer.Simple(0.5, function()
    include("dynsplatter/sh_override_funcs.lua")
    DynSplatterFullyInitialized = true
end) end)
--]]===========================================================================================]]


if SERVER then
    include("dynsplatter/sv_hooks.lua")
end


--]]===========================================================================================]]
-- Toolmenu --
if CLIENT then hook.Add("PopulateToolMenu", "PopulateToolMenu_DynamicBloodSplatter", function() spawnmenu.AddToolMenuOption("Options", "Gore", "Enhanced Blood", "Enhanced Blood", "", "", function(panel)
    panel:ControlHelp("\nServer")
    panel:CheckBox("Enable", "dynamic_blood_splatter_enable")
    panel:ControlHelp("Enable addon serverside, won't affect already spawned entities")
    panel:Help("")


    panel:ControlHelp("General")
    panel:NumSlider("Max Effects", "dynamic_blood_splatter_effect_count", 1, 8, 0)
    panel:ControlHelp("Max splatter effects per damage")
    panel:NumSlider("Max Damage", "dynamic_blood_splatter_sensitivity", 1, 500, 0)
    panel:ControlHelp("Amount of damage needed to get the maximum amount of splatters")
    panel:NumSlider("Red Decal Scale", "dynamic_blood_splatter_decal_scale", 0, 5, 2)
    panel:ControlHelp("Scale of red blood decals")
    panel:NumSlider("Alien Decal Scale", "dynamic_blood_splatter_aliendecal_scale", 0, 5, 2)
    panel:ControlHelp("Scale of alien blood decals")
    panel:CheckBox("Use Particle", "dynamic_blood_splatter_impact_fx")
    panel:ControlHelp("Enable regular particle effects")
    
    panel:Help("")


    panel:ControlHelp("Droplets")
    panel:NumSlider("Droplet Scale", "dynamic_blood_splatter_drip_scale", 0, 2, 2)
    panel:ControlHelp("Scale of blood droplets")
    panel:NumSlider("Droplet Velocity Multiplier", "dynamic_blood_splatter_force_mult", 0.5, 3, 2)
    panel:ControlHelp("Velocity multiplier for droplets")
    panel:NumSlider("Droplet Down Chance", "dynamic_blood_splatter_drop_chance", 0, 10, 0)
    panel:ControlHelp("Chance for an additional droplet that goes straight down to spawn")
    panel:NumSlider("Droplet Back Chance", "dynamic_blood_splatter_back_chance", 0, 10, 0)
    panel:ControlHelp("Chance for an additional droplet that goes in the opposite direction to spawn")
    panel:CheckBox("Droplet Impact Sound", "dynamic_blood_splatter_sound")
    panel:ControlHelp("Enable droplets emitting an impact sound")
    panel:CheckBox("Droplet Impact Particle", "dynamic_blood_splatter_particle_impact_fx")
    panel:ControlHelp("Enable droplets creating a impact particle")
    panel:CheckBox("Droplet Stain Entities", "dynamic_blood_splatter_stain_ents")
    panel:ControlHelp("Enable droplets staining entities (not just the world)")
    

    local resetButton = panel:Button("Reset Settings")
    --resetButton:DockMargin(0, 20, 0, 0)
    resetButton:SetHeight(25)
    panel:ControlHelp("Reset all the settings to their default values")

    function resetButton:DoClick()
        for _, v in ipairs({
            "dynamic_blood_splatter_impact_fx",
            "dynamic_blood_splatter_sound",
            "dynamic_blood_splatter_particle_impact_fx",
            "dynamic_blood_splatter_force_mult",
            "dynamic_blood_splatter_drip_scale",
            "dynamic_blood_splatter_decal_scale",
            "dynamic_blood_splatter_aliendecal_scale",
            "dynamic_blood_splatter_drop_chance",
            "dynamic_blood_splatter_back_chance",
            "dynamic_blood_splatter_sensitivity",
            "dynamic_blood_splatter_effect_count",
        }) do
            RunConsoleCommand(v, GetConVar(v):GetDefault())
        end
    end
end) end) end
--]]===========================================================================================]]