-- Guarded single-record component patch with complete table/record identity checks.
local M={}
function M.new(api,spec)
    assert(#spec.map%16==0 and #spec.original==spec.record_size)
    local target=spec.original
    local last=0
    for _,edit in ipairs(spec.edits) do
        local finish=edit.offset+#edit.bytes
        assert(edit.offset>=last and finish<=spec.record_size and #edit.bytes>0)
        edit.before=spec.original:sub(edit.offset+1,finish)
        target=target:sub(1,edit.offset)..edit.bytes..target:sub(finish+1)
        last=finish
    end
    local s={status='IDLE',writes=0,checks=0,retries=0,lease=nil}
    local function pointer(at)return api.pointer(api.read(at,8))end
    local function owner()return pointer(spec.game+spec.owner_rva)end
    local function map_matches(at)
        if not at then return false end
        local p=spec.probe_offset
        if api.read(at+p,32)~=spec.map:sub(p+1,p+32) then return false end
        for i=0,#spec.map-1,2048 do
            local chunk=spec.map:sub(i+1,i+2048)
            if api.read(at+i,#chunk)~=chunk then return false end
        end
        return true
    end
    local function context(l)
        return owner()==l.owner and pointer(l.slot)==l.table and map_matches(l.table)
    end
    function s:start()
        self.status='SCANNING';self.slot_index=0;self.matches={};self.current_owner=nil
        self.writes=0;self.checks=0;self.retries=0;self.lease=nil;self.error=nil
    end
    local function write_edits(self,lease,baseline,restore)
        local expected=baseline
        for _,edit in ipairs(spec.edits) do
            if not context(lease) or api.read(lease.record,spec.record_size)~=expected then return false end
            local bytes=restore and edit.before or edit.bytes
            local ok=api.write(lease.record+edit.offset,bytes)
            expected=expected:sub(1,edit.offset)..bytes..expected:sub(edit.offset+#bytes+1)
            if not ok or api.read(lease.record,spec.record_size)~=expected then return false end
        end
        return true
    end
    local function apply(self,who,hit)
        local record=hit.table+#spec.map+spec.record_index*spec.record_size
        local row=api.read(record,spec.record_size)
        if row~=spec.original then
            self.status=row==target and 'PREEXISTING_MODIFICATION_NOT_OWNED' or 'TEMPLATE_MISMATCH_NO_WRITE'
            return
        end
        local lease={owner=who,slot=hit.slot,table=hit.table,record=record}
        if not context(lease) or api.read(record,spec.record_size)~=spec.original then
            self.status='CONTEXT_CHANGED_NO_WRITE';return
        end
        self.lease=lease
        if not write_edits(self,lease,spec.original,false) or api.read(record,spec.record_size)~=target then
            self.status='WRITE_FAILED_OR_READBACK_MISMATCH'
            local after=api.read(record,spec.record_size)
            local owned=after~=nil
            if owned then
                for i=1,spec.record_size do
                    local b=after:byte(i)
                    if b~=spec.original:byte(i) and b~=target:byte(i) then owned=false;break end
                end
            end
            if owned and context(lease) then write_edits(self,lease,after,true) end
            if api.read(record,spec.record_size)==spec.original then self.lease=nil end
            return
        end
        self.writes=#spec.edits;self.status='APPLIED_'..spec.label
    end
    function s:step()
        if self.status=='APPLIED_'..spec.label then
            self.checks=self.checks+1
            if self.checks%300==0 and (not context(self.lease)
                or api.read(self.lease.record,spec.record_size)~=target) then
                self.status='APPLIED_RECORD_CHANGED_RESTART_REQUIRED'
            end
            return
        end
        if self.status=='WAITING_FOR_ENTITY_MANAGER' then self.status='SCANNING' end
        if self.status=='NO_MATCH_RETRYING' then
            self.delay=self.delay-1;if self.delay>0 then return end
            self.status='SCANNING';self.slot_index=0;self.matches={}
        end
        if self.status~='SCANNING' then return end
        local who=owner();if not who then self.status='WAITING_FOR_ENTITY_MANAGER';return end
        if self.current_owner~=who then self.current_owner=who;self.slot_index=0;self.matches={} end
        local count=(spec.scan_end-spec.scan_begin)/8
        for _=1,32 do
            if self.slot_index>=count then
                if #self.matches==1 then apply(self,who,self.matches[1]);return end
                self.status='NO_MATCH_RETRYING';self.delay=300;self.retries=self.retries+1;return
            end
            local slot=who+spec.scan_begin+self.slot_index*8;self.slot_index=self.slot_index+1
            local at=pointer(slot)
            if at and map_matches(at) then
                self.matches[#self.matches+1]={slot=slot,table=at}
                if #self.matches>1 then self.status='AMBIGUOUS_COMPONENT_TABLES_NO_WRITE';return end
            end
        end
    end
    function s:stop()
        local l=self.lease;if not l then return end
        if context(l) and api.read(l.record,spec.record_size)==target
            and write_edits(self,l,target,true)
            and api.read(l.record,spec.record_size)==spec.original then
            self.status='RESTORED_ON_SHUTDOWN';self.lease=nil;return
        end
        self.status='RESTORE_NOT_CONFIRMED'
    end
    return s
end
return M
