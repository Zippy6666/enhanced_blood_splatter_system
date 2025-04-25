--[[=========================== CONV MESSAGE START ===========================]]--
MissingConvMsg2 = CLIENT && function()

    Derma_Query(
        "This server does not have Zippy's Library installed, addons will function incorrectly!",

        "ZIPPY'S LIBRARY MISSING!",
        
        "Get Zippy's Library",

        function()
            gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3146473253")
        end,

        "Close"
    )

end or nil

hook.Add("PlayerInitialSpawn", "MissingConvMsg2", function( ply )

    if file.Exists("autorun/conv.lua", "LUA") then return end

    local sendstr = 'MissingConvMsg2()'
    ply:SendLua(sendstr)

end)
--[[============================ CONV MESSAGE END ============================]]--

AddCSLuaFile("dynsplatter/sh_override_funcs.lua")
AddCSLuaFile("dynsplatter/sh_hooks.lua")
include("dynsplatter/sh_hooks.lua")
if SERVER then
    include("dynsplatter/sv_hooks.lua")
end
hook.Add("InitPostEntity", "DynSplatterOverrideFuncs", function() timer.Simple(0.5, function()
    include("dynsplatter/sh_override_funcs.lua")
    DynSplatterFullyInitialized = true
end) end)

game.AddParticles("particles/blood_impact.pcf")
PrecacheParticleSystem("blood_impact_synth_01")

DynSplatterEnabledCvar = CreateConVar("dynamic_blood_splatter_enable_mod", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY))
DynSplatterPredictCvar = CreateConVar("dynamic_blood_splatter_predict", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY))

-- Toolmenu --
if CLIENT then hook.Add("PopulateToolMenu", "PopulateToolMenu_DynamicBloodSplatter", function() spawnmenu.AddToolMenuOption("Options", "Gore", "Enhanced Blood", "Enhanced Blood", "", "", function(panel)
    panel:ControlHelp("\nServer")
    panel:CheckBox("Enable", "dynamic_blood_splatter_enable_mod")
    panel:ControlHelp("Enable addon serverside, won't affect already spawned entities")
    panel:CheckBox("Predict", "dynamic_blood_splatter_predict")
    panel:ControlHelp("Enable prediction serverside")
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