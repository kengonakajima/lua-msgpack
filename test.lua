
local pretty
local res,err = pcall( function()
                          pretty = require "pl.pretty"
                          require "pl.strict"
                       end)

local mp = require "msgpack"

local display = function(m,x)
                   local _t = type(x)
                   io.stdout:write(string.format("\n%s: %s ",m,_t))
                   if _t == "table" and pretty then pretty.dump(x) else print(x) end
                end

local printf = function(p,...)
                  io.stdout:write(string.format(p,...)); io.stdout:flush()
               end

local rand_raw = function(len)
                    local t = {}
                    for i=1,len do t[i] = string.char(math.random(0,255)) end
                    return table.concat(t)
                 end
local strdump = function(s)
                   local out = ""
                   
                   for i=1,#s do
                      if i>4 and i < #s-4 then
                         if (i%1000)==0 then
                            out = out .. "."
                         end
                      else
                         out = out .. s:byte( i ) .. " "
                      end
                   end
                   return out
                end


-- copy(right) from penlight tablex module! for test in MOAI environment. 
function deepcompare(t1,t2,ignore_mt,eps)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' then
        if ty1 == 'number' and eps then return abs(t1-t2) < eps end
        return t1 == t2
    end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1,v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not deepcompare(v1,v2,ignore_mt,eps) then return false end
    end
    for k2,v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not deepcompare(v1,v2,ignore_mt,eps) then return false end
    end
    return true
end


local msgpack_cases = {
   false,true,nil,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,127,127,255,65535,
   4294967295,-32,-32,-128,-32768,-2147483648, 0.0,-0.0,1.0,-1.0, 
   "a","a","a","","","",
   {0},{0},{0},{},{},{},{},{},{},{a=97},{a=97},{a=97},{{}},{{"a"}},
}

local data = {
   true,
   false,
   42,
      -42,
   0.1,
   0.79, 
   "Hello world!",
   {},
   {true,false,42,-42,0.79,"Hello","World!"},
   {{"multi","level",{"lists","used",45,{{"trees"}}},"work",{}},"too"},
   {foo="bar",spam="eggs"},
   {nested={maps={"work","too"}}},
   {"we","can",{"mix","integer"},{keys="and"},{2,{maps="as well"}}},
   -1,
   -128,
   -32768,
   -32769,
   -2147483648,
127,
255,
65535,
4294967295,
7.9e+35,
-7.9e+35,
msgpack_cases
}

local offset,res

-- Custom tests
printf("Custom tests ")
for i=0,#data do -- 0 tests nil!
   print("test i:",i)
   local packed = mp.pack(data[i])
   offset,res = mp.unpack(packed)
   assert(offset,"decoding failed." )
   if not deepcompare(res,data[i]) then
      display("expected",data[i])
      display("found",res)
      print( "packed len:", #packed )
      for j=1,#packed do
         print( packed[j] )
      end      
      assert(false,string.format("wrong value %d",i))
   end
end
print(" OK")


-- long str in table (regression)
printf("regression test : str in a table")
repeater = function(n)
              local s = ""
              for i=1,n do s = s .. "abcd" end
              return s
           end
data = {
   { data = "abcd", d2=1, d3="abcd" },
   { data = "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcd", d2=1, d3="abcd" },
   { data = repeater(20000), d2=1, d3="abcd" }
}
for i=1,#data do
   print("regtest i:", i,  " len:", #data[i].data )
   local packed = mp.pack(data[i])
   print( "packed len:", #packed )
   print( "packed:", strdump( packed ))
   local offset,res = mp.unpack( packed )
   assert(offset or res,"decoding failed")
   print( "res.data:", strdump( res.data ) )
   assert( res.data:sub(1,1) == "a" )
   assert( res.data:sub( #res.data, #res.data ) == "d" )
   assert( res.d2 == 1 )
   assert( res.d3 == "abcd" )
   if not deepcompare(res,data[i]) then
      print( "expect string len:", string.len(data[i].data) )
      print( "data.data:", strdump( data[i].data ))
      print( "packed:", strdump( packed ) )
      print( "found string len:", string.len(res.data ) )
      print( "res.data: ", strdump( res.data ) )

      assert(false, "fail")
   end
end
print("OK")
   
-- Corrupt data test
print("corrupt data test")
local s = mp.pack(data)
local corrupt_tail = string.sub( s, 1, 10 )
offset,res = pcall(function() mp.unpack(s) end)
assert(offset)
offset,res = pcall(function() mp.unpack(corrupt_tail) end)
assert(not offset)
-- corrupt string test
ary = { 147,1,172,115,101,116,85,82,76,80,114,101,102,105,120,129,163,117,
        114,108,180,104,116,116,112,58,47,47,49,48,46,48,46,49,46,55,58,56,48,57,49 }
s = ""
for i,v in ipairs(ary) do
   s = s .. string.char(v)
end
offset,nr,res = pcall(function() return mp.unpack(s) end)
assert(offset)
assert(nr==#ary)
assert(res[1]==1)
assert(res[2]=="setURLPrefix")
assert(res[3].url == "http://10.0.1.7:8091")
corrupt_tail = string.sub( s, 1,31 )
offset,nr,res = pcall(function() return mp.unpack(corrupt_tail) end)
assert(not offset)

-- corrupt test 3 (fixraw and raw16 and raw32)
s = mp.pack( "shorterthan32bytes" )
offset,nr,res = pcall(function() return mp.unpack(s) end)
assert(offset)
assert(res=="shorterthan32bytes")
corrupt_tail = string.sub( s, 1, 5 )
offset,nr,res  = pcall( function() return mp.unpack(corrupt_tail) end)
assert(not offset)

local origs = "longer than 32bytes and shorter than 64k bytes string"
s = mp.pack( origs )
offset,nr,res = pcall(function() return mp.unpack(s) end)
assert(offset)
corrupt_tail = string.sub( s, 1, 5 )
offset,nr,res = pcall( function() return mp.unpack( corrupt_tail ) end)
assert(not offset)

origs = rand_raw(70000)
s = mp.pack(origs)
offset,nr,res = pcall(function() return mp.unpack(s) end)
assert(offset)
corrupt_tail = string.sub( s, 1, 10 )
offset,nr,res = pcall(function() return mp.unpack( corrupt_tail ) end)
assert(not offset)


-- Empty data test
print("empty test")
local offset,res = mp.unpack(mp.pack({}))
assert(offset==1)
assert(res[1]==nil)



-- Integer tests

printf("Integer tests ")

local nb_test = function(n,sz)
                   local packed = mp.pack(n)
                   if string.len(packed) ~= sz then error("packed size mismatch") end
                   offset,res = mp.unpack(packed)
                   assert(offset,"decoding failed")
                   if not res == n then
                      assert(false,string.format("wrong value %d, expected %d",res,n))
                   end
                   assert(offset == sz,string.format(
                             "wrong size %d for number %d (expected %d)",
                             offset,n,sz
                       ))
                end




printf(".")
for n=0,127 do -- positive fixnum
   nb_test(n,1)
end

printf(".")
for n=128,255 do -- uint8
   nb_test(n,2)
end

printf(".")
for n=256,65535 do -- uint16
   nb_test(n,3)
end

-- uint32
printf(".")
for n=65536,65536+100 do
   nb_test(n,5)
end
for n=4294967295-100,4294967295 do
   nb_test(n,5)
end

-- no 64 bit!
--printf(".")  
--for n=4294967296,4294967296+100 do -- uint64
--  nb_test(n,9)
--end

printf(".")
for n=-1,-32,-1 do -- negative fixnum
   nb_test(n,1)
end

printf(".")
for n=-33,-128,-1 do -- int8
   nb_test(n,2)
end

printf(".")
for n=-129,-32768,-1 do -- int16
   nb_test(n,3)
end

-- int32
printf(".")
for n=-32769,-32769-100,-1 do
   nb_test(n,5)
end
for n=-2147483648+100,-2147483648,-1 do
   nb_test(n,5)
end


print("OK")

-- Floating point tests
print("Floating point tests")

printf(".")
for i=1,1000 do
  local n = math.random()*200-100
  nb_test(n,9)
end
print(" OK")

-- Raw tests

print("Raw tests ")
local raw_test = function(raw,overhead)
                    local offset,res = mp.unpack(mp.pack(raw))
                    assert(offset,"decoding failed")
                    if not res == raw then
                       assert(false,string.format("wrong raw (len %d - %d)",#res,#raw))
                    end
                    assert(offset-#raw == overhead,string.format(
                              "wrong overhead %d for #raw %d (expected %d)",
                              offset-#raw,#raw,overhead
                        ))
                 end

printf(".")
for n=0,31 do -- fixraw
   raw_test(rand_raw(n),1)
end





-- raw16
printf("test raw16:")
for n=32,32+100 do
   raw_test(rand_raw(n),3)
end
for n=65535-5,65535 do
   printf(".")   
   raw_test(rand_raw(n),3)
end

-- raw32
printf("test raw32:")
for n=65536,65536+5 do
   printf(".")      
   raw_test(rand_raw(n),5)
end
print("OK")




print("skip 64bit int test")
--printf(".")
--for n=-2147483649,-2147483649-100,-1 do -- int64
--  nb_test(n,9)
--end
--print(" OK")






-- below: too slow
-- for n=4294967295-100,4294967295 do
--   raw_test(rand_raw(n),5)
-- end
---print(" OK")

-- Table tests

--printf("Table tests ")
--print(" TODO")

-- Floating point tests
--printf("Map tests ")
--print(" TODO")

-- From MessagePack test suite
-- no uint64 and double, skip it !

-- local cases_dir = pathx.abspath(pathx.dirname(arg[0]))
-- local case_files = {
--   standard = pathx.join(cases_dir,"cases.mpac"),
--   compact = pathx.join(cases_dir,"cases_compact.mpac"),
-- }
-- local i,f,bindata,decoded
-- local ncases = #msgpack_cases
-- for case_name,case_file in pairs(case_files) do
--   printf("MsgPack %s tests ",case_name)
--   f = assert(io.open(case_file,'rb'))
--   bindata = f:read("*all")
--   f:close()
--   offset,i = 0,0
--   while true do
--     i = i+1
--     printf(".")
--     offset,res = mp.unpack(bindata,offset)
--     if not offset then break end
--     if not tablex.deepcompare(res,msgpack_cases[i]) then
--       display("expected",msgpack_cases[i])
--       display("found",res)
--       assert(false,string.format("wrong value %d",i))
--     end
--   end
--   assert(
--     i-1 == ncases,
--     string.format("decoded %d values instead of %d",i-1,ncases)
--   )
--   print(" OK")
-- end
