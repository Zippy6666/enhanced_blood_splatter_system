local ENT = FindMetaTable("Entity")
local Cvar = FindMetaTable("ConVar")


DynSplatterEntGetBloodColor = DynSplatterEntGetBloodColor or ENT.GetBloodColor
DynSplatterEntSetBloodColor = DynSplatterEntSetBloodColor or ENT.SetBloodColor
DynSplatterCvarGetInt = DynSplatterCvarGetInt or Cvar.GetInt
DynSplatterReturnEngineBlood = false



function ENT:DisableEngineBlood()

    DynSplatterEntSetBloodColor(self, DONT_BLEED)

end


function ENT:GetBloodColor()

    if DynSplatterReturnEngineBlood then
        DynSplatterReturnEngineBlood = false
        -- print( self,  DynSplatterEntGetBloodColor(self) )
        return DynSplatterEntGetBloodColor(self) or DONT_BLEED
    end


    if self:GetNWBool("DynSplatter") then
        return self:GetNWInt("EnhancedSplatter_BloodColor", -1)
    end


    return DynSplatterEntGetBloodColor(self) or DONT_BLEED
    
end


function ENT:SetBloodColor( col )

    self:SetNWInt("EnhancedSplatter_BloodColor", col)

    if !self:GetNWBool("DynSplatter") then
        DynSplatterEntSetBloodColor(self, col)
    end

end


function Cvar:GetInt( ... )

    -- Disable decals and particles for hlr corpses

    if self == GetConVar("vj_hlr1_corpse_effects") then return 0 end
    return DynSplatterCvarGetInt(self, ...)

end




DynSplatterFullyInitialized = true