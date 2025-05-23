local PARTICLE = CreateConVar("dynamic_blood_splatter_impact_fx", "1", FCVAR_ARCHIVE)
local RED_DECAL_SCALE = CreateConVar("dynamic_blood_splatter_decal_scale", "1", FCVAR_ARCHIVE)
local YELLOW_DECAL_SCALE = CreateConVar("dynamic_blood_splatter_aliendecal_scale", "1.25", FCVAR_ARCHIVE)
local DRIP_SCALE = CreateConVar("dynamic_blood_splatter_drip_scale", "0.75", FCVAR_ARCHIVE)
local DROP_CHANCE = CreateConVar("dynamic_blood_splatter_drop_chance", "5", FCVAR_ARCHIVE)
local SPLAT_BACK_CHANCE = CreateConVar("dynamic_blood_splatter_back_chance", "6", FCVAR_ARCHIVE)
local IMPACT_SOUND = CreateConVar("dynamic_blood_splatter_sound", "1", FCVAR_ARCHIVE)
local IMPACT_PARTICLE = CreateConVar("dynamic_blood_splatter_particle_impact_fx", "0", FCVAR_ARCHIVE)
local SENSITIVITY = CreateConVar("dynamic_blood_splatter_sensitivity", "100", FCVAR_ARCHIVE)
local COUNT = CreateConVar("dynamic_blood_splatter_effect_count", "5", FCVAR_ARCHIVE)
local FORCE_MULT = CreateConVar("dynamic_blood_splatter_force_mult", "1.25", FCVAR_ARCHIVE)
local STAIN_ENTS = CreateConVar("dynamic_blood_splatter_stain_ents", "1", FCVAR_ARCHIVE)


-- Use default blood stains as materials for the effect, and decals.
local blood_materials = {}
for i = 1,8 do
    local imat = Material("decals/blood"..i)
    table.insert(blood_materials, imat)
end


-- Use default alien blood stains as materials for the effect, and decals.
local alienblood_materials = {}
for i = 1,6 do
    local imat = Material("decals/yblood"..i)
    table.insert(alienblood_materials, imat)
end


local sparkMat = Material("effects/spark")


-- Random decal lenght and width:
local decal_randscale = {min=0.55,max=1.25}


-- Default HL2 impact effects:
local blood_impact_fx = {
    [BLOOD_COLOR_RED] = "blood_impact_red_01",
    [BLOOD_COLOR_ANTLION] = "blood_impact_antlion_01",
    [BLOOD_COLOR_ANTLION_WORKER] = "blood_impact_antlion_worker_01",
    [BLOOD_COLOR_GREEN] = "blood_impact_green_01",
    [BLOOD_COLOR_ZOMBIE] = "blood_impact_zombie_01",
    [BLOOD_COLOR_YELLOW] = "blood_impact_yellow_01",
}


local alien_blood_colors = {
    [BLOOD_COLOR_ANTLION] = true,
    [BLOOD_COLOR_ANTLION_WORKER] = true,
    [BLOOD_COLOR_GREEN] = true,
    [BLOOD_COLOR_ZOMBIE] = true,
    [BLOOD_COLOR_YELLOW] = true,
}


local CustomBloodMaterials = {}


-- Sounds:
local blood_drop_sounds = {
    "enh_blood_splatter_drips/drip_01.wav",
    "enh_blood_splatter_drips/drip_02.wav",
    "enh_blood_splatter_drips/drip_03.wav",
    "enh_blood_splatter_drips/drip_04.wav",
    "enh_blood_splatter_drips/drip_05.wav",
    "enh_blood_splatter_drips/drip_06.wav",
    "enh_blood_splatter_drips/drip_07.wav",
    "enh_blood_splatter_drips/drip_08.wav",
}




function EFFECT:Init( data )
    local ent = data:GetEntity()
    local flags = data:GetFlags()-1
    local blood_color = (IsValid(ent) && ent:GetBloodColor()) or flags
    local pos = data:GetOrigin()
    local magnitude = data:GetMagnitude()
    local damage = data:GetRadius()
    local dataNrm = data:GetNormal()
    local physdamage = magnitude < 1


    -- Particle:
    local CustomBloodParticle = IsValid(ent) && ent:GetNWString( "DynamicBloodSplatter_CustomBlood_Particle", false )
    local blood_particle = CustomBloodParticle or blood_impact_fx[blood_color]

    if PARTICLE:GetBool() && blood_particle then
        ParticleEffect(blood_particle, pos, (-dataNrm):Angle())
    end

    -- Decide blood materials to use:
    local blood_mats
    local do_decal = true
    local CustomBloodDecal = IsValid(ent) && ent:GetNWString( "DynamicBloodSplatter_CustomBlood_Decal", false )

    if blood_color == BLOOD_COLOR_RED then

        -- Red blood
        blood_mats = table.Copy(blood_materials)

    elseif alien_blood_colors[blood_color] then

        -- Yellow blood
        blood_mats = table.Copy(alienblood_materials)

    elseif blood_color == BLOOD_COLOR_MECH then

        blood_mats = {sparkMat}
        do_decal = false

    elseif CustomBloodDecal then

        -- Custom blood
        -- Make new custom decal materials as they are discovered:
        
        local decal_mat_name = util.DecalMaterial(CustomBloodDecal)
        CustomBloodMaterials[CustomBloodDecal] = CustomBloodMaterials[CustomBloodDecal] or {}


        if !CustomBloodMaterials[CustomBloodDecal][decal_mat_name] then
            local imat = Material(decal_mat_name)
            CustomBloodMaterials[CustomBloodDecal][decal_mat_name] = imat
        end

        blood_mats = table.Copy(CustomBloodMaterials[CustomBloodDecal])

    end


    -- No blood materials, can't do effect
    if !blood_mats then return end


    local particle_scale = DRIP_SCALE:GetFloat()
    local emitter = ParticleEmitter(pos, false)
    local hasDoneCollide = {}


    for effectNum = 1, Lerp( math.Clamp(damage / SENSITIVITY:GetInt(), 0, 1), 1, COUNT:GetInt() ) do

        -- Chance for additional splatter effect going in the opposite direction:
        local splash_back = SPLAT_BACK_CHANCE:GetBool() && magnitude>0.9 && math.random( 1, SPLAT_BACK_CHANCE:GetInt() )==1


        -- Chance for additional splatter effect that drops to the floor under the target:
        local drip = DROP_CHANCE:GetBool() && math.random( 1, DROP_CHANCE:GetInt() )==1


        for i = 1, 3 do
            if !drip && i==2 then continue end
            if !splash_back && i==3 then continue end


            local force = (i==2 && math.random(-35,35)) or (i==3 && -65*magnitude) or (150*magnitude)
            -- print("force", force)
            local function forceVec()
                return dataNrm*force + VectorRand(-force*0.35, force*0.35)
            end


            if !physdamage then
                force = force*FORCE_MULT:GetFloat()
            end


            -- The blood that exits the body:
            for i2 = 1, 5*magnitude do

                local blood_material = table.Random(blood_mats)
                local length = math.Rand(20, 60)
                local particle = emitter:Add( blood_material, pos )
                particle:SetDieTime( 1.8 )
                particle:SetStartSize( math.Rand(1.9, 3.8)*particle_scale )
                particle:SetEndSize(0)
                particle:SetStartLength( length*particle_scale*0.45 )
                particle:SetEndLength( length*particle_scale )
                particle:SetGravity( Vector(0,0,-500) )
                particle:SetVelocity( forceVec() )
                particle:SetCollide( true )
                

                if i2==1 then
                    local function collideFunc( _, collidepos, normal, collEnt )
                        local effIndex = tostring(effectNum).."_"..tostring(i)
                        if hasDoneCollide[effIndex] then return end


                        if do_decal then
                            local decal_scale = ( blood_color==BLOOD_COLOR_RED && RED_DECAL_SCALE:GetFloat() )
                            or ( alien_blood_colors[blood_color] && YELLOW_DECAL_SCALE:GetFloat() ) or 1

                            
                            util.DecalEx(
                                blood_material,
                                collEnt or Entity(0),
                                collidepos,
                                normal,
                                Color(255, 255, 255),
                                math.Rand(decal_randscale.min, decal_randscale.max)*decal_scale,
                                math.Rand(decal_randscale.min, decal_randscale.max)*decal_scale
                            )


                            if IMPACT_PARTICLE:GetBool() && blood_particle then
                                ParticleEffect(blood_particle, collidepos, (-normal):Angle())
                            end

                            if IMPACT_SOUND:GetBool() then
                                sound.Play(table.Random(blood_drop_sounds), collidepos, 77, math.random(95, 120), 0.7)
                            end
                        end


                        -- print(effIndex.. " done")
                        hasDoneCollide[effIndex] = true
                    end


                    -- Simulate particle hitting something else than the world
                    if STAIN_ENTS:GetBool() then
                        local traceEnd = pos + forceVec()
                        local function tracer()
                            return util.TraceLine({
                                start = pos,
                                endpos = traceEnd,
                                filter = ent,
                            })
                        end

                        local tr = tracer()
                        if tr.Hit && !tr.HitWorld then timer.Simple(tr.Fraction, function()

                            local tr2 = tracer()
                            if tr2.Hit && !tr2.HitWorld then
                                collideFunc(nil, tr2.HitPos, tr2.HitNormal, tr2.Entity)
                            end

                        end) end
                    end


                    -- First particle should do the collide code:
                    particle:SetCollideCallback(collideFunc)
                end
            end
        end
    end

    
    emitter:Finish()
end


function EFFECT:Think() return false end


function EFFECT:Render() end

