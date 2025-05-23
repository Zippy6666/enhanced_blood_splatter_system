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
        local norm = dir:GetNormalized()
        local effectdata = EffectData()
        effectdata:SetOrigin( pos )
        effectdata:SetNormal( norm )
        effectdata:SetMagnitude( intensity )
        effectdata:SetRadius(damage)
        effectdata:SetEntity( ent )
        effectdata:SetFlags( ent:GetBloodColor()+1 )
        util.Effect("dynamic_blood_splatter_effect", effectdata, true, true )

    end
end

local function DMG_IsDissolveDamage( dmginfo )
    return dmginfo:IsDamageType(DMG_DISSOLVE) or conv.thisEntOrWorld(dmginfo:GetInflictor()):GetClass()=="prop_combine_ball"
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

    -- Dissolve damage
    if DMG_IsDissolveDamage(dmginfo) then
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
        CustomDecal = ent.CustomBlood_Decal && ent.CustomBlood_Decal[1]
        CustomParticle = ent.CustomBlood_Particle && ent.CustomBlood_Particle[1]

    elseif ent.IsZBaseNPC or ent.IsZBaseRag then
        CustomDecal = ent.CustomBloodDecals
        CustomParticle = ent.CustomBloodParticles && ent.CustomBloodParticles[1]
    
    end

    -- Hunter ragdoll should always have "blood_impact_synth_01" if nothing else was provided
    if !CustomParticle && ent:GetClass() == "prop_ragdoll" && ent:GetModel()=="models/hunter.mdl" then
        CustomParticle = "blood_impact_synth_01"
    end

    if CustomDecal && ent.DynSplatter_LastCustomDecal != CustomDecal then
        ent:SetNWString( "DynamicBloodSplatter_CustomBlood_Decal", CustomDecal )
        ent.DynSplatter_LastCustomDecal = CustomDecal
    end

    if CustomParticle && ent.DynSplatter_LastCustomParticle != CustomParticle then
        -- Precache
        if !PrecachedParticles[CustomParticle] then
            PrecachedParticles[CustomParticle] = true
            PrecacheParticleSystem(CustomParticle)
        end

        ent:SetNWString( "DynamicBloodSplatter_CustomBlood_Particle", CustomParticle )
        ent.DynSplatter_LastCustomParticle = CustomParticle

    end
end

local function Damage( ent, dmginfo, pos )
    -- Don't bleed on burn damage for example:
    if DMG_NoBleed(dmginfo) then return end

    -- Don't bleed dissolving entities:
    if bit.band( ent:GetFlags(), FL_DISSOLVING ) == FL_DISSOLVING then return end

    local damage = dmginfo:GetDamage()
    local force = dmginfo:GetDamageForce()
    local infl = dmginfo:GetInflictor()

    if force:IsZero() && IsValid(infl) then
        force = ent:GetPos() - dmginfo:GetDamagePosition()
        debugoverlay.Line(ent:WorldSpaceCenter(), ent:WorldSpaceCenter()+force)
    end

    local bullet_damage_type = IsBulletDamage( dmginfo )
    local do_on_bullet_effect = !DynSplatterPredictCvar:GetBool()

    if bullet_damage_type && !do_on_bullet_effect then
        return
    end

    local phys_damage_type = dmginfo:IsDamageType(DMG_CRUSH)
    local do_on_phys_effect = damage > 10 && phys_damage_type

    local isWepDMG = (IsValid(infl) && infl:IsWeapon())
    local isCrossBowDMG = (IsValid(infl) && infl:GetClass() == "crossbow_bolt")

    -- Put blood effect on damage position if it was bullet damage or physics damage or if the inflictor was a weapon, otherwise put it in the center of the entity.
    local blood_pos = pos or ( (bullet_damage_type or isWepDMG or do_on_phys_effect or isCrossBowDMG) && dmginfo:GetDamagePosition() ) or ent:WorldSpaceCenter()
    local magnitude = do_on_phys_effect&&0.5 or 1.2

    if ( do_on_phys_effect or (!phys_damage_type && damage > 0) ) then
        EnhancedSplatter( ent, blood_pos, force, magnitude, phys_damage && 1 or damage )
    end
end

hook.Add("ScaleNPCDamage", "EnhancedSplatter", function(npc, iHitGr, dmginfo)
    if !npc:GetNWBool("DynSplatter") then return end

    if !npc.EnhancedSplatter_BulletHits then
        npc:CONV_TempVar("EnhancedSplatter_BulletHits", {}, 0)
    end

    if istable(npc.EnhancedSplatter_BulletHits) then
        table.insert(npc.EnhancedSplatter_BulletHits, {pos=dmginfo:GetDamagePosition(), dir=dmginfo:GetDamageForce():GetNormalized()})
    end
end)

hook.Add("EntityTakeDamage", "EnhancedSplatter", function( ent, dmginfo )
    if !ent:GetNWBool("DynSplatter") then return end

    NetworkCustomBlood( ent )

    if istable(ent.EnhancedSplatter_BulletHits) then
        for _, v in ipairs(ent.EnhancedSplatter_BulletHits) do
            Damage(ent, dmginfo, v.pos)
        end
    else
        Damage( ent, dmginfo )
    end
end)

hook.Add("OnEntityCreated", "OnEntityCreated_DynamicBloodSplatter", function( ent )
    if !DynSplatterFullyInitialized then return end
    if !DynSplatterEnabledCvar:GetBool() then return end

    timer.Simple(0.1, function()
        if !IsValid(ent) then return end

        if ent.IsVJBaseSNPC then
            -- function ent:SpawnBloodParticles() end
            -- function ent:SpawnBloodDecal() end

        elseif ent.IsZBaseNPC then
            function ent:CustomBleed() end

        end

        DynSplatterReturnEngineBlood = true
        local EngineBloodColor = ent:GetBloodColor()

        if ent:IsNPC() or ent:IsPlayer() then
            ent:SetBloodColor(EngineBloodColor)
            ent:DisableEngineBlood()
            ent:SetNWBool("DynSplatter", true)
        end

        NetworkCustomBlood( ent )
    end)
end)

hook.Add("CreateEntityRagdoll", "CreateEntityRagdoll_DynamicBloodSplatter", function( own, ragdoll )
    if !DynSplatterEnabledCvar:GetBool() then return end

    if own.IsVJBaseSNPC then
        ragdoll.CustomBlood_Decal = own.CustomBlood_Decal
        ragdoll.CustomBlood_Particle = own.CustomBlood_Particle

    elseif own.IsZBaseNPC then
        ragdoll.CustomBloodDecals = own.CustomBloodDecals
        ragdoll.CustomBloodParticles = own.CustomBloodParticles

    end

    ragdoll:SetBloodColor(own:GetBloodColor())
    ragdoll:SetNWBool("DynSplatter", true)
end)

hook.Add("PlayerSpawn", "RemoveEngineBlood", function( ply )
    if DynSplatterEnabledCvar:GetBool() then
        if DynSplatterFullyInitialized then
            DynSplatterReturnEngineBlood = true
            local EngineBloodColor = ply:GetBloodColor()
            
            ply:DisableEngineBlood()
            ply:SetBloodColor(EngineBloodColor)
            ply:SetNWBool("DynSplatter", true)

        end

    else
        ply:SetNWBool("DynSplatter", false)

    end
end)