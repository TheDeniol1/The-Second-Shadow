local Trace=require('subject_trace')
local names={[10]='/Game/Levels/X/LVL_A',[11]='LVL_A_C',[12]='ExecuteUbergraph_LVL_A',
 [20]='LVL_A',[21]='PersistentLevel',[22]='BP_Zipline',[23]='BP_Zipline_C',[24]='BP_Television'}
local queue,observed,logs,grabs={},{},{},{}
local stats={0,0}
local native={
 subjectObserve=function(_,on)observed[#observed+1]=on;return on end,
 subjectNext=function()return table.remove(queue,1)end,
 subjectStats=function()return stats[1],stats[2]end,
 subjectGrabs=function(_,a,b)grabs[#grabs+1]={a,b}end,
}
local distances
local t=Trace.new({native=native,log=function(s)logs[#logs+1]=s end,
 name=function(i)return names[i]end,distances=function(path)if distances then return distances(path)end end})
local function entry(actor,counts)
 local e={graph=500,actor=actor,g1=12,g2=11,g3=10,a1=actor==1 and 22 or 24,a2=21,a3=20,a4=10,c1=23,
  code=0x49f,depth=0,routed=0,none=0,p1=0,p2=0,both=0,self1=0,self2=0}
 if actor==2 then e.a1n=3 end
 for k,v in pairs(counts)do e[k]=v end
 return e
end
t:update(0)
assert(#observed==0 and #logs==0,'nothing is observed until enabled')
t:setEnabled(true,0)
assert(observed[1]==true and t.enabled,'enabling installs the native observer')
queue={entry(1,{p2=2,routed=1})}
distances=function(path)
 assert(path=='/Game/Levels/X/LVL_A.LVL_A:PersistentLevel.BP_Zipline','actor paths follow the outer chain')
 return 412.6,80.2
end
t:update(1)
local line=logs[#logs]
assert(line:find('Sujeto: P2 | /Game/Levels/X/LVL_A.LVL_A_C:ExecuteUbergraph_LVL_A @0x49f',1,true),'graph path, verdict and offset: '..line)
assert(line:find('(BP_Zipline_C)',1,true) and line:find('P2=2',1,true) and line:find('redirigido=1',1,true)
 and line:find('dist P1=412 P2=80',1,true),'counts, routing and distances are reported: '..line)
distances=nil
local count=#logs
queue={entry(1,{p2=3})}
t:update(1.5)
assert(#logs==count,'the drain runs once per second')
t:update(2.1)
assert(#logs==count,'a repeated P2 key waits before logging again')
queue={entry(1,{p2=9})}
t:update(7)
assert(#logs==count+1,'growth is reported again after the repeat interval')
queue={entry(2,{p1=4})}
t:update(8)
assert(logs[#logs]:find('BP_Television_2',1,true) and logs[#logs]:find('Sujeto: P1',1,true),
 'a first P1 sighting is logged once with the FName number suffix')
queue={entry(2,{p1=40})}
t:update(20)
assert(#logs==count+2,'P1-only lookups never repeat')
queue={entry(2,{p1=40,both=1})}
t:update(30)
assert(logs[#logs]:find('ambos=1',1,true),'ambiguous frames are reported')
queue={}
for i=1,40 do queue[i]=entry(100+i,{p2=1}) end
count=#logs
t:update(31)
assert(#logs==count+25,'one drain logs at most 25 lines')
t:update(32)
assert(#logs==count+25,'lines over the budget are skipped, not delayed')
stats={52,3}
t:mark()
assert(logs[#logs]:find('52 consultas distintas, 3 descartadas',1,true),'F8 reports totals')
names[24]=nil
queue={entry(2,{p2=1})}
t:update(40)
t:setEnabled(false,41)
assert(observed[#observed]==false and not t.enabled,'disabling releases the native observer')
queue={entry(300,{p2=1})}
t:update(50)
assert(#queue==1,'a disabled trace never drains')
t:setEnabled(true,70)
t:holding(0,903);t:holding(0,903);t:holding(12,903)
assert(#grabs==2 and grabs[1][2]==903 and grabs[2][1]==12,'held objects reach the native observer only when they change')
queue={entry(4,{none=6,grab2=6,slot1=-1,slot2=-1}),entry(5,{both=3,slot1=0x58,slot2=0x60})}
t:update(71)
assert(logs[#logs-1]:find('sujeta P1=0 P2=6',1,true) and not logs[#logs-1]:find('ranura',1,true),'held-object matches are reported: '..logs[#logs-1])
assert(logs[#logs]:find('ranura P1=0x58 P2=0x60',1,true),'both players report their frame slots: '..logs[#logs])
queue={entry(4,{none=9,grab2=9,slot1=-1,slot2=-1})}
t:update(77)
assert(logs[#logs]:find('P2=9',1,true),'a growing held-object count is reported after the repeat interval')
t:setEnabled(false,80)
t:holding(1,2)
assert(#grabs==2,'a disabled trace sends no held objects')
native.subjectObserve=function()return false end
t:setEnabled(true,60)
assert(not t.enabled,'a failed install keeps the trace off')
print('PASS: subject trace opt-in lifecycle, paths, verdicts, held objects, frame slots, repeat throttle, line budget and F8 totals.')
