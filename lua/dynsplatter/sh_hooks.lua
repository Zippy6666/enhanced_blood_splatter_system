local isSingleplayer = game.SinglePlayer()
local isMultiplayer = !isSingleplayer
local didBulletCode = false



local function ShouldBulletImpact( ent )
    if isSingleplayer && SERVER then
        return true
    end

    if CLIENT && isMultiplayer then
        return true
    end

    local entOwn = ent:GetOwner()
    local isPlyFiring = ent:IsPlayer() or (ent:IsWeapon() && IsValid(entOwn) && entOwn:IsPlayer())
    if SERVER && isMultiplayer && !isPlyFiring then
        return true
    end

    return false
end


hook.Add("EntityFireBullets", "dynsplatter", function( ent, data )

    if didBulletCode then return end
    if !DynSplatterEnabledCvar:GetBool() then return end
    if !ShouldBulletImpact(ent) then return end


    data.Callback = conv.wrapFunc2( data.Callback or function(_, attacker, tr, dmginfo) end, nil, function(_, attacker, tr, dmginfo)

        if !IsValid(tr.Entity) then return end

        local effectdata = EffectData()
        effectdata:SetOrigin( tr.HitPos )
        effectdata:SetNormal( -tr.HitNormal )
        effectdata:SetMagnitude( 1.2 )
        effectdata:SetRadius(dmginfo:GetDamage())
        effectdata:SetEntity( tr.Entity )
        effectdata:SetFlags( tr.Entity:GetBloodColor()+1 )
        util.Effect("dynamic_blood_splatter_effect", effectdata, true, true )

    end)


    didBulletCode = true
    hook.Run("EntityFireBullets", ent, data)
    didBulletCode = false


    return true

end)

