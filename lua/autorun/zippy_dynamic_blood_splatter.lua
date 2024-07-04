local EnabledCvar = CreateConVar("dynamic_blood_splatter_enable_mod", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY))


--[[
==================================================================================================
                    MESSAGE TEMPLATE
==================================================================================================
--]]


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
elseif SERVER && !file.Exists("autorun/conv.lua", "LUA") then
    -- Conv lib not on on server, send message to clients
    hook.Add("PlayerInitialSpawn", "convenienceerrormsg", function( ply )
        local sendstr = 'MissingConvMsg()'
        ply:SendLua(sendstr)
    end)
end


--[[
==================================================================================================
                    SERVER CODE
==================================================================================================
--]]

if SERVER then

    local function EnhancedSplatter( ent, pos, dir, intensity, damage )

        if ent:GetBloodColor() == BLOOD_COLOR_MECH then
    
            -- Just a spark
            local spark = ents.Create("env_spark")
            spark:SetPos(pos)
            spark:Spawn()
            spark:Fire("StartSpark", "", 0)
            spark:Fire("StopSpark", "", 0.001)
            SafeRemoveEntityDelayed(spark, 0.1)
    
        else
    
            norm = dir:GetNormalized()
    
    
            -- Enhanced splatter lisgooo
            local effectdata = EffectData()
            effectdata:SetOrigin( pos )
            effectdata:SetNormal( norm )
            effectdata:SetMagnitude( intensity )
            effectdata:SetRadius(damage)
            effectdata:SetEntity( ent )
            util.Effect("dynamic_blood_splatter_effect", effectdata, true, true )
    
        end
    
    end
    
    
    local function DMG_NoBleed( dmginfo )
    
        -- Fire damage
        if dmginfo:IsDamageType(DMG_BURN) && dmginfo:IsDamageType(DMG_DIRECT) then
            return true
        end
    
        -- Drown damage
        if dmginfo:IsDamageType(DMG_DROWN) or dmginfo:IsDamageType(DMG_DROWNRECOVER) then
            return true
        end
    
        return false
    
    end
    
    
    local function IsBulletDamage( dmginfo )
    
        return dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_BUCKSHOT)
    
    end
    
    
    local PrecachedParticles = {}
    local function NetworkCustomBlood( ent )
    
        local CustomDecal
        local CustomParticle
    
    
        if ent.IsVJBaseSNPC or ent.IsVJBaseCorpse then
            -- VJ
            CustomDecal = ent.CustomBlood_Decal && ent.CustomBlood_Decal[1]
            CustomParticle = ent.CustomBlood_Particle && ent.CustomBlood_Particle[1]
        elseif ent.IsZBaseNPC or ent.IsZBaseRag then
            -- ZBASE
            CustomDecal = ent.CustomBloodDecals
            CustomParticle = ent.CustomBloodParticles && ent.CustomBloodParticles[1]
        end
    
        -- Hunter ragdoll should always have "blood_impact_synth_01" if nothing else was provided
        if !CustomParticle && ent:GetClass() == "prop_ragdoll" && ent:GetModel()=="models/hunter.mdl" then
            CustomParticle = "blood_impact_synth_01"
        end
    
    
        -- Network if custom decal updated
        if CustomDecal && ent.DynSplatter_LastCustomDecal != CustomDecal then
            ent:SetNWString( "DynamicBloodSplatter_CustomBlood_Decal", CustomDecal )
            ent.DynSplatter_LastCustomDecal = CustomDecal
        end
    
    
        -- Network if custom particle updated
        if CustomParticle && ent.DynSplatter_LastCustomParticle != CustomParticle then
    
            -- Precache particle
            if !PrecachedParticles[CustomParticle] then
                PrecachedParticles[CustomParticle] = true
                PrecacheParticleSystem(CustomParticle)
            end
    
            ent:SetNWString( "DynamicBloodSplatter_CustomBlood_Particle", CustomParticle )
            ent.DynSplatter_LastCustomParticle = CustomParticle
    
        end
    
    end
    
    
    local function Damage( ent, dmginfo )
        if DMG_NoBleed(dmginfo) then return end -- Don't bleed if forbidden damage type, such as burn
        if bit.band( ent:GetFlags(), FL_DISSOLVING ) == FL_DISSOLVING then return end -- Don't bleed dissolving entities:
    
        local damage = dmginfo:GetDamage()
        local force = dmginfo:GetDamageForce()
        local infl = dmginfo:GetInflictor()
    
        -- If force is not provided, calculate force based on damage position
        if force:IsZero() && IsValid(infl) then
            force = ent:GetPos() - dmginfo:GetDamagePosition()
        end
    
        local phys_damage_type = dmginfo:IsDamageType(DMG_CRUSH)
    
        local phys_damage = damage > 10 && phys_damage_type
        local weapon_damage = (IsValid(infl) && infl:IsWeapon())
        local crossbow_damage = (IsValid(infl) && infl:GetClass() == "crossbow_bolt")
    
        -- Put blood effect on damage position if it was bullet damage or physics damage or if the inflictor was a weapon, otherwise put it in the center of the entity.
        local blood_pos = ( (IsBulletDamage( dmginfo ) or weapon_damage or phys_damage or crossbow_damage) && dmginfo:GetDamagePosition() ) or ent:WorldSpaceCenter()
        local magnitude = phys_damage&&0.5 or 1.2
    
        if phys_damage or (!phys_damage_type && damage > 0) then
            EnhancedSplatter( ent, blood_pos, force, magnitude, phys_damage && 1 or damage )
        end
    end
    
    
    local function regHit( npc, pos )
        npc.DynSplatter_Hits = npc.DynSplatter_Hits or {}
        table.insert(npc.DynSplatter_Hits, pos)
        conv.callNextTick(function() npc.DynSplatter_Hits = nil end)
    end
    
    
    hook.Add("ScaleNPCDamage", "EnhancedSplatter", function( npc, hitgr, dmginfo )
        if !EnabledCvar:GetBool() then return end
        if !npc:GetNWBool("DynSplatter") then return end
        regHit(npc, dmginfo:GetDamagePosition())
    end)
    
    
    hook.Add("ScalePlayerDamage", "EnhancedSplatter", function( ply, hitgr, dmginfo )
        if !EnabledCvar:GetBool() then return end
        if !ply:GetNWBool("DynSplatter") then return end
        regHit(ply, dmginfo:GetDamagePosition())
    end)
    
    
    hook.Add("EntityTakeDamage", "EnhancedSplatter", function( ent, dmginfo )
        if !EnabledCvar:GetBool() then return end
        if !ent:GetNWBool("DynSplatter") then return end
    
    
        NetworkCustomBlood( ent )
    
    
        if ent.DynSplatter_Hits then
    
            local infl = dmginfo:GetInflictor()
            if !IsValid(infl) then infl = dmginfo:GetAttacker() end
    
            for _, pos in ipairs(ent.DynSplatter_Hits) do
                local dmginfo2 = DamageInfo()
                dmginfo2:SetAttacker(dmginfo:GetAttacker())
                dmginfo2:SetInflictor(infl)
                dmginfo2:SetDamage(dmginfo:GetDamage() / #ent.DynSplatter_Hits)
                dmginfo2:SetDamagePosition(pos)
                dmginfo2:SetDamageType(dmginfo:GetDamageType())
                dmginfo2:SetDamageForce(dmginfo:GetDamageForce())
                Damage(ent, dmginfo2)
            end

            ent.DynSplatter_Hits = nil
            ent:CONV_TempVar("DynSplatter_DidShotgunHits", true, 0)
    
        elseif ent.DynSplatter_DidShotgunHits then

            MsgN("Did shotgun fix...")

        else

    
            Damage( ent, dmginfo )
    
        end
    end)
    
    
    hook.Add("OnEntityCreated", "OnEntityCreated_DynamicBloodSplatter", function( ent )
        if !EnabledCvar:GetBool() then return end

        if ent:IsNPC() or ent:IsNextBot() then
            ent:SetNWBool("DynSplatter", true)
        end
    
    
        -- timer.Simple(0.1, function()
        --     if !IsValid(ent) then return end
    
    
        --     if ent.IsVJBaseSNPC then
    
        --         function ent:SpawnBloodParticles() end
        --         function ent:SpawnBloodDecal() end
    
        --     elseif ent.IsZBaseNPC then
    
        --         function ent:CustomBleed() end
    
        --     end
    
    
        --     DynSplatterReturnEngineBlood = true
        --     local EngineBloodColor = ent:GetBloodColor()
    
    
        --     if ent:IsNPC() or ent:IsPlayer() then
        --         ent:SetBloodColor(EngineBloodColor)
        --         ent:DisableEngineBlood()
        --         ent:SetNWBool("DynSplatter", true)
        --     end
    
    
        --     NetworkCustomBlood( ent )
        -- end)
    end)
    
    
    hook.Add("CreateEntityRagdoll", "CreateEntityRagdoll_DynamicBloodSplatter", function( own, ragdoll )
        if !EnabledCvar:GetBool() then return end
    
    
        -- if own.IsVJBaseSNPC then
    
        --     ragdoll.CustomBlood_Decal = own.CustomBlood_Decal
        --     ragdoll.CustomBlood_Particle = own.CustomBlood_Particle
    
        -- elseif own.IsZBaseNPC then
    
        --     ragdoll.CustomBloodDecals = own.CustomBloodDecals
        --     ragdoll.CustomBloodParticles = own.CustomBloodParticles
    
        -- end
    
    
        -- ragdoll:SetBloodColor(own:GetBloodColor())
        -- ragdoll:SetNWBool("DynSplatter", true)
    end)
    
    
    hook.Add("PlayerSpawn", "RemoveEngineBlood", function( ply )
        if !EnabledCvar:GetBool() then return end

        -- if GetConVar("dynamic_blood_splatter_enable"):GetBool() then
    
        --     if DynSplatterFullyInitialized then
    
        --         DynSplatterReturnEngineBlood = true
        --         local EngineBloodColor = ply:GetBloodColor()
                
        --         ply:DisableEngineBlood()
        --         ply:SetBloodColor(EngineBloodColor)
        --         ply:SetNWBool("DynSplatter", true)
    
        --     end
    
        -- else
    
        --     ply:SetNWBool("DynSplatter", false)
    
        -- end
    end)

end

--[[
==================================================================================================
                    TOOL MENU
==================================================================================================
--]]


-- Toolmenu --
if CLIENT then hook.Add("PopulateToolMenu", "PopulateToolMenu_DynamicBloodSplatter", function() spawnmenu.AddToolMenuOption("Options", "Gore", "Enhanced Blood", "Enhanced Blood", "", "", function(panel)
    panel:ControlHelp("\nServer")
    panel:CheckBox("Enable", "dynamic_blood_splatter_enable")
    -- panel:ControlHelp("Enable addon serverside, won't affect already spawned entities")

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
    panel:CheckBox("Droplet Impact Particle", "dynamic_blood_splatter_particle_impact_fx")
    panel:ControlHelp("Enable droplets creating a impact particle")
    panel:CheckBox("Droplet Stain Entities", "dynamic_blood_splatter_stain_ents")
    panel:ControlHelp("Enable droplets staining entities (not just the world)")
    

    local resetButton = panel:Button("Reset Settings")
    resetButton:SetHeight(25)
    panel:ControlHelp("Reset all the settings to their default values")


    function resetButton:DoClick()
        for _, v in ipairs({
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

