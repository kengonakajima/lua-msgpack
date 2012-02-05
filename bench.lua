local mp = require "msgpack"
local os = require "os"



function makeiary(n)
   local out={}
   for i=1,n do table.insert(out,math.floor(i-n/2)) end
   return out
end
function makedary(n)
   local out={}
   for i=1,n do table.insert(out, 1.5e+35 * i ) end
   return out
end

function makestr(n)
   local out=""
   for i=1,n-1 do out = out .. "a" end
   out = out .. "b"
   return out
end

local nloop = 5000
local datasets = {

   
   { "empty", {}, nloop },
   
   { "iary1", {1}, nloop },
   { "iary10", {-5,-4,-3,-2,-1,0,1,2,3,4}, nloop },
   { "iary100", makeiary(100), nloop/10 },
   { "iary1000", makeiary(1000), nloop/100 },
   { "iary10000", makeiary(10000), nloop/1000 },
   
   { "dary1", {1.5e+35}, 100 },
   { "dary10", makedary(10), 50 },
   { "dary100", makedary(100), 5 },
   { "dary1000", makedary(1000), 5 },
      
   { "str1", { "a"}, nloop },
   { "str10", { makestr(10) }, nloop },
   { "str100", { makestr(100) }, nloop },
   { "str1000", { makestr(1000) }, nloop },
   { "str10000", { makestr(10000) }, nloop/10 },
   { "str20000", { makestr(20000) }, nloop/10 },
   { "str30000", { makestr(30000) }, nloop/10 },
   { "str40000", { makestr(40000) }, nloop/100 },
   { "str80000", { makestr(80000) }, nloop/100 },
}

for i,v in ipairs(datasets) do
   st = os.clock()
   local n = v[3]
   local offset,res
   for j=1,n do
      offset,res = mp.unpack( mp.pack(v[2] ) )
   end
   assert(offset)   
   et = os.clock()
   print( v[1], (et-st), "sec", n/(et-st), "times/sec" )
end
