if rawget(_G,'SuzukaEMSBoost') then return end
local state={version='1.0.9',status='INITIALIZING',policies={}}
rawset(_G,'SuzukaEMSBoost',state)
local loader=rawget(_G,'CowboyBingusModLoader')

local function report()
    local ok,err=pcall(function()
        local file=assert(loader.open_log('SuzukaEMSBoost.log'),'log_unavailable')
        file:write('Suzuka‘s EMS boos '..state.version..'\nSTATUS='..state.status..'\n')
        file:write('TARGET=2 salvos x 4 bombs; bomb interval 0.25 s; salvo interval 3 s; area_size 15; fire_height 3000 -> 2700\n')
        if state.sha then file:write('GAME_SHA256='..state.sha..'\n') end
        for _,policy in ipairs(state.policies) do
            file:write('EMS_BOMBARDMENT='..policy.status..' writes='..policy.writes..'\n')
        end
        if state.error then file:write('ERROR='..state.error..'\n') end
        file:close()
    end)
    if not ok then state.log_error=tostring(err);print('Suzuka EMS log error: '..state.log_error) end
end

local ok,err=pcall(function()
    assert(loader and loader.api==1,'Bingus Shared Loader API 1 required')
    local api=create_api()
    local game=assert(api.module('game.dll'),'game.dll unavailable')
    state.sha=api.module_hash(game)
    assert(state.sha==module_sha256,'unsupported_game_dll_no_write')
    local spec=component_specs[1]
    spec.game=game;spec.owner_rva=owner_rva
    local policy=component_policy.new(api,spec)
    state.policies={policy};policy:start()
    state.status='APPLYING'

    local original_update=assert(rawget(_G,'update'),'update unavailable')
    local original_shutdown=rawget(_G,'shutdown')
    local last=''
    local function pack(...)return {n=select('#',...),...}end
    local function restore()
        local good,problem=pcall(function()policy:stop()end)
        if not good then state.error=tostring(problem) end
        return good and not policy.lease
    end
    _G.update=function(...)
        local result=pack(original_update(...))
        if state.status=='APPLYING' or state.status=='APPLIED_ALL' then
            local good,problem=pcall(function()
                policy:step()
                local current=policy.status
                if current=='APPLIED_'..spec.label then state.status='APPLIED_ALL'
                elseif current=='SCANNING' or current=='WAITING_FOR_ENTITY_MANAGER'
                    or current=='NO_MATCH_RETRYING' then state.status='APPLYING'
                else
                    state.error=current
                    state.status=restore() and 'DISABLED_POLICY_FAILED_RESTORED'
                        or 'DISABLED_RESTORE_UNCONFIRMED'
                end
            end)
            if not good then
                state.error=tostring(problem)
                state.status=restore() and 'DISABLED_RUNTIME_ERROR_RESTORED'
                    or 'DISABLED_RESTORE_UNCONFIRMED'
            end
        end
        local now=state.status..'|'..policy.status
        if now~=last then last=now;report() end
        return unpack(result,1,result.n)
    end
    _G.shutdown=function(...)
        restore();report()
        if original_shutdown then return original_shutdown(...) end
    end
end)
if not ok then state.status='DISABLED_NO_WRITE';state.error=tostring(err) end
report()
