local mp = require "msgpack"
local os = require "os"

local nLoop = 30

function makeiary(n)
   local out={}
   for i=1,n do table.insert(out,i) end
   return out
end
function makestr(n)
   local out=""
   for i=1,n-1 do out = out .. "a" end
   out = out .. "b"
   return out
end

local datasets = {
   { "empty", {} },
   { "iary1", {1} },
   { "iary10", {1,2,3,4,5,6,7,8,9,10} },
   { "iary100", makeiary(100) },
   { "iary1000", makeiary(1000) },
   { "iary10000", makeiary(10000) },
   { "str1", { "a"} },
   { "str10", { makestr(10) } },
   { "str100", { makestr(100) } },
   { "str1000", { makestr(1000) } },
   { "str10000", { makestr(10000) } },
}

for i,v in ipairs(datasets) do
   st = os.clock()
   local offset,res
   for j=1,nLoop do
      offset,res = mp.unpack( mp.pack(v[2] ) )
   end
   assert(offset)   
   et = os.clock()
   print( v[1], (et-st), "sec", nLoop/(et-st), "times/sec" )
end
