local table = require("table")
local string = require("string")

local luabit
local res,err = pcall( function() return require "bit" end )

if not res then
   print("msgpack: no bitops. falling back: load local luabit.")
   luabit = require "./luabit" -- local
else
   luabit = require "bit"
end


-- cache bitops
local bor,band,bxor,rshift = luabit.bor,luabit.band,luabit.bxor,luabit.brshift
if not rshift then -- luajit differ from luabit
   rshift = luabit.rshift
end 

-- endianness
local LITTLE_ENDIAN = true
local rcopy = function(dst,src,len)
  local n = len-1
  for i=0,n do dst[i] = src[n-i] end
end

-- buffer

local buffer={}

local buf_append_tbl = function(destt,t)
                          for i=1,#t do
                             table.insert(destt, t[i])
                          end
                       end

local buf_append_str = function(destt,s,l)
                          local t = {}
                          for i=1,l do
                             table.insert( destt, string.byte(s,i) )
                          end
                       end

local buf_append_intx
if LITTLE_ENDIAN then
   buf_append_intx = function(destt,n,x,h)
                        local t = {h}
                        for i=x-8,0,-8 do t[#t+1] = band(rshift(n,i),0xff) end
                        buf_append_tbl(destt,t)
                     end
else
   buf_append_intx = function(destt,n,x,h)
                        local t = {h}
                        for i=0,x-8,8 do t[#t+1] = band(rshift(n,i),0xff) end
                        buf_append_tbl(destt,t)
                     end
end
local buf_append_double = function(destt,n)
                             -- assume double
                             local b = doubleto8bytes(n)
--                             print( string.format( "doubleto8bytes: %x %x %x %x %x %x %x %x", b:byte(1), b:byte(2), b:byte(3), b:byte(4), b:byte(5), b:byte(6), b:byte(7), b:byte(8)))
                             buf_append_tbl(destt,{0xcb})
                             buf_append_str(destt,string.reverse(b), 8 ) -- make big endian double precision 
                          end





--- IEEE 754

-- out little endian
function doubleto8bytes(x)
   local function grab_byte(v)
      return math.floor(v / 256),
      string.char(math.mod(math.floor(v), 256))
   end
   local sign = 0
   if x < 0 then sign = 1; x = -x end
   local mantissa, exponent = math.frexp(x)
   if x == 0 then -- zero
      mantissa, exponent = 0, 0
   elseif x == 1/0 then
      mantissa, exponent = 0, 2047
   else
      mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 53)
      exponent = exponent + 1022
   end
--   print("doubleto8bytes: exp:", exponent, "mantissa:", mantissa , "sign:", sign )
   
   local v, byte = "" -- convert to bytes
   x = mantissa
   for i = 1,6 do
      x, byte = grab_byte(x); v = v..byte -- 47:0
   end
   x, byte = grab_byte(exponent * 16 + x);  v = v..byte -- 55:48
   x, byte = grab_byte(sign * 128 + x); v = v..byte -- 63:56
   return v
end

function bitstofrac(ary)
   local x = 0
   local cur = 0.5
   for i,v in ipairs(ary) do
      x = x + cur * v
      cur = cur / 2
   end
   return x   
end

function bytestobits(ary)
   local out={}
   for i,v in ipairs(ary) do
      for j=0,7,1 do
         table.insert(out, luabit.band( luabit.brshift(v,7-j), 1 ) )
      end
   end
   return out
end

function dumpbits(ary)
   local s=""
   for i,v in ipairs(ary) do
      s = s .. v .. " "
      if (i%8)==0 then s = s .. " " end
   end
   print(s)
end

-- get little endian
function bytestodouble(v)
   -- sign:1bit
   -- exp: 11bit (2048, bias=1023)
   local sign = math.floor(v:byte(8) / 128)
   local exp = luabit.band( v:byte(8), 127 ) * 16 + luabit.brshift( v:byte(7), 4 ) - 1023 -- bias
   -- frac: 52 bit
   local fracbytes = {
      luabit.band( v:byte(7), 15 ), v:byte(6), v:byte(5), v:byte(4), v:byte(3), v:byte(2), v:byte(1) -- big endian
   }
   local bits = bytestobits(fracbytes)
   
   for i=1,4 do table.remove(bits,1) end

--   dumpbits(bits)

   if sign == 1 then sign = -1 else sign = 1 end
   
   local frac = bitstofrac(bits)
   if exp == -1023 and frac==0 then return 0 end
   if exp == 1024 and frac==0 then return 1/0 *sign end
   local real = math.ldexp(1+frac,exp)

--   print( "sign:", sign, "exp:", exp,  "frac:", frac, "real:", real )
   return real * sign
end



--- packers

local packers = {}

packers.dynamic = function(data)
  return packers[type(data)](data)
end

packers["nil"] = function(data)
  buf_append_tbl(buffer,{0xc0})
end

packers.boolean = function(data)
  if data then -- pack true
    buf_append_tbl(buffer,{0xc3})
  else -- pack false
    buf_append_tbl(buffer,{0xc2})
  end
end

packers.number = function(n)
  if math.floor(n) == n then -- integer
    if n >= 0 then -- positive integer
      if n < 128 then -- positive fixnum
        buf_append_tbl(buffer,{n})
      elseif n < 256 then -- uint8
        buf_append_tbl(buffer,{0xcc,n})
      elseif n < 65536 then -- uint16
        buf_append_intx(buffer,n,16,0xcd)
      elseif n < 4294967296 then -- uint32
        buf_append_intx(buffer,n,32,0xce)
      else -- lua cannot handle uint64, so double
--        buf_append_intx(buffer,n,64,0xcf)
         buf_append_double(buffer,n)
      end
    else -- negative integer
      if n >= -32 then -- negative fixnum
        buf_append_tbl(buffer,{bor(0xe0,n)})
      elseif n >= -128 then -- int8
        buf_append_tbl(buffer,{0xd0,n})
      elseif n >= -32768 then -- int16
        buf_append_intx(buffer,n,16,0xd1)
      elseif n >= -2147483648 then -- int32
        buf_append_intx(buffer,n,32,0xd2)
      else -- luca cannot handle int64, so double
--        buf_append_intx(buffer,n,64,0xd3)
         buf_append_double(buffer,n)
      end
    end
  else -- floating point
     buf_append_double(buffer,n)
  end
end

packers.string = function(data)
  local n = #data
  if n < 32 then
    buf_append_tbl(buffer,{bor(0xa0,n)})
  elseif n < 65536 then
    buf_append_intx(buffer,n,16,0xda)
  elseif n < 4294967296 then
    buf_append_intx(buffer,n,32,0xdb)
  else
    error("overflow")
  end
  buf_append_str(buffer,data,n)
end

packers["function"] = function(data)
  error("unimplemented")
end

packers.userdata = function(data)
  error("unimplemented")
end

packers.thread = function(data)
  error("unimplemented")
end

packers.table = function(data)
  local is_map,ndata,nmax = false,0,0
  for k,_ in pairs(data) do
    if type(k) == "number" then
      if k > nmax then nmax = k end
    else is_map = true end
    ndata = ndata+1
  end
  if is_map then -- pack as map
    if ndata < 16 then
      buf_append_tbl(buffer,{bor(0x80,ndata)})
    elseif ndata < 65536 then
      buf_append_intx(buffer,ndata,16,0xde)
    elseif ndata < 4294967296 then
      buf_append_intx(buffer,ndata,32,0xdf)
    else
      error("overflow")
    end
    for k,v in pairs(data) do
      packers[type(k)](k)
      packers[type(v)](v)
    end
  else -- pack as array
    if nmax < 16 then
      buf_append_tbl(buffer,{bor(0x90,nmax)})
    elseif nmax < 65536 then
      buf_append_intx(buffer,nmax,16,0xdc)
    elseif nmax < 4294967296 then
      buf_append_intx(buffer,nmax,32,0xdd)
    else
      error("overflow")
    end
    for i=1,nmax do packers[type(data[i])](data[i]) end
  end
end

-- types decoding

local types_map = {
    [0xc0] = "nil",
    [0xc2] = "false",
    [0xc3] = "true",
    [0xca] = "float",
    [0xcb] = "double",
    [0xcc] = "uint8",
    [0xcd] = "uint16",
    [0xce] = "uint32",
    [0xcf] = "uint64",
    [0xd0] = "int8",
    [0xd1] = "int16",
    [0xd2] = "int32",
    [0xd3] = "int64",
    [0xda] = "raw16",
    [0xdb] = "raw32",
    [0xdc] = "array16",
    [0xdd] = "array32",
    [0xde] = "map16",
    [0xdf] = "map32",
  }

local type_for = function(n)
  if types_map[n] then return types_map[n]
  elseif n < 0xc0 then
    if n < 0x80 then return "fixnum_pos"
    elseif n < 0x90 then return "fixmap"
    elseif n < 0xa0 then return "fixarray"
    else return "fixraw" end
  elseif n > 0xdf then return "fixnum_neg"
  else return "undefined" end
end

local types_len_map = {
  uint16 = 2, uint32 = 4, uint64 = 8,
  int16 = 2, int32 = 4, int64 = 8,
  float = 4, double = 8,
}

--- unpackers

local unpackers = {}

local unpack_number = function(buf,offset,ntype,nlen)
--                         print("unpack_number: ntype:", ntype, " nlen:", nlen, "ofs:",offset, "nbuffer:",#buffer )
                         local b1,b2,b3,b4,b5,b6,b7,b8
                         if nlen>=2 then
                            b1 = buffer[offset+1]
                            b2 = buffer[offset+2]
                         end
                         if nlen>=4 then
                            b3 = buffer[offset+3]
                            b4 = buffer[offset+4]
                         end
                         if nlen>=8 then
                            b5 = buffer[offset+5]
                            b6 = buffer[offset+6]                            
                            b7 = buffer[offset+7]
                            b8 = buffer[offset+8]
                         end
                            
                         if ntype == "uint16_t" then
--                            print( string.format("u16 bytes: %x %x", b1, b2 ))
                            return b1 * 256 + b2
                         elseif ntype == "uint32_t" then
--                            print( string.format("u32 bytes: %x %x %x %x ", b1, b2, b3, b4 ))
                            return b1*65536*256 + b2*65536 + b3 * 256 + b4
                         elseif ntype == "int16_t" then
                            local n = b1 * 256 + b2
                            local nn = (65536 - n)*-1
                            if nn == -65536 then nn = 0 end
--                            print( string.format("i16 bytes: %x %x", b1, b2 ),n,nn)
                            return nn
                         elseif ntype == "int32_t" then
                            local n = b1*65536*256 + b2*65536 + b3 * 256 + b4
                            local nn = ( 4294967296 - n ) * -1
                            if nn == -4294967296 then nn = 0 end
--                            print( string.format("i32 bytes: %x %x %x %x ", b1, b2, b3, b4 ), n, nn )
                            return nn
                         elseif ntype == "double_t" then
--                            print( string.format("doublebytes networked: %x %x %x %x %x %x %x %x", b1, b2, b3, b4,b5,b6,b7,b8 ) )
                            local s = ""..string.char(b8)..string.char(b7)..string.char(b6)..string.char(b5)..string.char(b4)..string.char(b3)..string.char(b2)..string.char(b1)
--                            print(" unpack_double: slen:", string.len(s), b1, b2, b3, b4, b5, b6, b7, b8 )
                            local n = bytestodouble( s )
                            return n
                         else
                            error("unpack_number: not impl:" .. ntype )
                         end
                      end



local unpacker_number = function(buf,offset)
  local obj_type = type_for(buffer[offset+1])
  local nlen = types_len_map[obj_type]
  local ntype
  if (obj_type == "float") then
     error("float is not implemented")
  else
     ntype = obj_type .. "_t"
  end
--  print("unpacker_number:  ntype:", ntype , " nlen:", nlen )
  return offset+nlen+1,unpack_number(buf,offset+1,ntype,nlen)
end

local unpack_map = function(buf,offset,n)
  local r = {}
  local k,v
  for i=1,n do
    offset,k = unpackers.dynamic(buf,offset)
    offset,v = unpackers.dynamic(buf,offset)
    r[k] = v
  end
  return offset,r
end

local unpack_array = function(buf,offset,n)
  local r = {}
  for i=1,n do offset,r[i] = unpackers.dynamic(buf,offset) end
  return offset,r
end

unpackers.dynamic = function(buf,offset)
--                       print("unpackers.dynamic: buf:", buf, " ofs:", offset )
                       if offset >= #buf then return nil,nil end
                       local obj_type = type_for(buf[offset+1])
--                       print("unpackers.dynamic: type:", obj_type, string.format(" typebyte:%x", buf[offset+1]))
                       return unpackers[obj_type](buf,offset)
                    end

unpackers.undefined = function(buf,offset)
                         error("unimplemented")
                      end

unpackers["nil"] = function(buf,offset)
                      return offset+1,nil
                   end

unpackers["false"] = function(buf,offset)
                        return offset+1,false
                     end

unpackers["true"] = function(buf,offset)
                       return offset+1,true
                    end

unpackers.fixnum_pos = function(buf,offset)
                          return offset+1,buffer[offset+1]
                       end

unpackers.uint8 = function(buf,offset)
                     return offset+2,buffer[offset+2]
                  end

unpackers.uint16 = unpacker_number
unpackers.uint32 = unpacker_number
unpackers.uint64 = unpacker_number

unpackers.fixnum_neg = function(buf,offset)
                          -- alternative to cast below:
                          -- return offset+1,-band(bxor(buf.data[offset],0x1f),0x1f)-1
                          local n = buffer[offset+1]
                          local nn = ( 256 - n ) * -1
                          return offset+1,  nn
                       end

unpackers.int8 = function(buf,offset)
                    local i = buffer[offset+2]
                    if i > 127 then
                       i = (256 - i ) * -1
                    end
                    return offset+2, i
                 end

unpackers.int16 = unpacker_number
unpackers.int32 = unpacker_number
unpackers.int64 = unpacker_number

unpackers.float = unpacker_number
unpackers.double = unpacker_number

unpackers.fixraw = function(buf,offset)
  local n = band(buf[offset+1],0x1f)
  local b = ""
  for i=1,n do
     b = b .. string.char(buffer[offset+i+1])
  end
  return offset+n+1,b
end

unpackers.raw16 = function(buf,offset)
  local n = unpack_number(buf,offset+1,"uint16_t",2)
  local b=""
--  print("unpackers.raw16: n:", n, string.format("%x", buf[offset+1]) )  
  for i=1,n do
     b = b .. string.char(buf[offset+i+1+2])
  end
  return offset+n+3,b 
end

unpackers.raw32 = function(buf,offset)
  local n = unpack_number(buf,offset+1,"uint32_t",4)
  local b=""
--  print("unpackers.raw32: n:", n, string.format("%x %x %x %x %x", buf[offset+1], buf[offset+2], buf[offset+3], buf[offset+4], buf[offset+5]) )
  for i=1,n do     
     b = b .. string.char(buf[offset+i+1+4])
  end
  return offset+n+5,b
end

unpackers.fixarray = function(buf,offset)
  return unpack_array(buf,offset+1,band(buffer[offset+1],0x0f))
end

unpackers.array16 = function(buf,offset)
  return unpack_array(buf,offset+3,unpack_number(buf,offset+1,"uint16_t",2))
end

unpackers.array32 = function(buf,offset)
  return unpack_array(buf,offset+5,unpack_number(buf,offset,"uint32_t",4))
end

unpackers.fixmap = function(buf,offset)
  return unpack_map(buf,offset+1,band(buffer[offset+1],0x0f))
end

unpackers.map16 = function(buf,offset)
  return unpack_map(buf,offset+3,unpack_number(buf,offset,"uint16_t",2))
end

unpackers.map32 = function(buf,offset)
  return unpack_map(buf,offset+5,unpack_number(buf,offset,"uint32_t",4))
end

-- Main functions

local ljp_pack = function(data)
                    buffer={}
                    packers.dynamic(data)
                    local s = ""

                    for i,v in ipairs(buffer) do
--                       print( "ljp_pack: loop: i:", i, " char:", string.format("%x",v) )
                       s = s .. string.char(band(v,0xff))
                    end
--                    print("ljp_pack: buf:", string.format( "%x", buffer[1] ) )
                    return s
                 end

local ljp_unpack = function(s,offset)
                      if offset == nil then offset = 0 end
                      if type(s) ~= "string" then return false,"invalid argument" end
                      buffer={}
                      buf_append_str(buffer,s,#s)
--                      print("ljp_unpack: buflen:", #buffer )
                      local data
                      offset,data = unpackers.dynamic(buffer,offset)
                      return offset,data
                   end

msgpack = {
  pack = ljp_pack,
  unpack = ljp_unpack,
}

return msgpack

