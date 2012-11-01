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

local tostr = string.char

local double_decode_count = 0
local double_encode_count = 0

-- cache bitops
local bor,band,bxor,rshift = luabit.bor,luabit.band,luabit.bxor,luabit.brshift
if not rshift then -- luajit differ from luabit
  rshift = luabit.rshift
end 

local function byte_mod(x,v)
  if x < 0 then
    x = x + 256
  end
  return (x%v)
end


-- buffer
local strbuf="" -- for unpacking
local strary={} -- for packing


local function strary_append_int16(n,h)
  if n < 0 then
     n = n + 65536
  end
  table.insert( strary, tostr(h, math.floor(n / 256), n % 256 ) )
end
local function strary_append_int32(n,h)
  if n < 0 then
     n = n  + 4294967296
  end
  table.insert( strary, tostr(h,
      math.floor(n/16777216),
      math.floor(n/65536) %256,
      math.floor(n/256) % 256,
      n % 256 ) )
end   

local strary_append_double = function(n)
  -- assume double
  double_encode_count = double_encode_count + 1
  local b = doubleto8bytes(n)
  --                             print( string.format( "doubleto8bytes: %x %x %x %x %x %x %x %x", b:byte(1), b:byte(2), b:byte(3), b:byte(4), b:byte(5), b:byte(6), b:byte(7), b:byte(8)))
  table.insert( strary, tostr(0xcb))
  table.insert( strary, string.reverse(b) )   -- reverse: make big endian double precision
end


--- IEEE 754

-- out little endian
function doubleto8bytes(x)
  local function grab_byte(v)
    return math.floor(v / 256), tostr(math.fmod(math.floor(v), 256))
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

local function bitstofrac(ary)
  local x = 0
  local cur = 0.5
  for i,v in ipairs(ary) do
     x = x + cur * v
     cur = cur / 2
  end
  return x   
end

local function bytestobits(ary)
  local out={}
  for i,v in ipairs(ary) do
    for j=0,7,1 do
      table.insert(out, band( rshift(v,7-j), 1 ) )
    end
  end
  return out
end

local function dumpbits(ary)
  local s=""
  for i,v in ipairs(ary) do
    s = s .. v .. " "
    if (i%8)==0 then s = s .. " " end
  end
  print(s)
end

-- get little endian
local function bytestodouble(v)
  -- sign:1bit
  -- exp: 11bit (2048, bias=1023)
  local sign = math.floor(v:byte(8) / 128)
  local exp = band( v:byte(8), 127 ) * 16 + rshift( v:byte(7), 4 ) - 1023 -- bias
  -- frac: 52 bit
  local fracbytes = {
    band( v:byte(7), 15 ), v:byte(6), v:byte(5), v:byte(4), v:byte(3), v:byte(2), v:byte(1) -- big endian
  }
  local bits = bytestobits(fracbytes)
   
  for i=1,4 do table.remove(bits,1) end

--   dumpbits(bits)

  if sign == 1 then sign = -1 else sign = 1 end
   
  local frac = bitstofrac(bits)
  if exp == -1023 and frac==0 then return 0 end
  if exp == 1024 and frac==0 then return 1/0 *sign end
  local real = math.ldexp(1+frac,exp)

--   print( "sign:", sign, "exp:", exp,  "frac:", frac, "real:", real, "v:", v:byte(1),v:byte(2),v:byte(3),v:byte(4),v:byte(5),v:byte(6),v:byte(7),v:byte(8) )
  return real * sign
end

--- packers

local packers = {}

packers.dynamic = function(data)
  local t = type(data)
  return packers[t](data)
end

packers["nil"] = function(data)
  table.insert( strary, tostr(0xc0))
end

packers.boolean = function(data)
  if data then -- pack true
    table.insert( strary, tostr(0xc3))
  else -- pack false
    table.insert( strary, tostr(0xc2))
  end
end

packers.number = function(n)
  if math.floor(n) == n then -- integer
    if n >= 0 then -- positive integer
      if n < 128 then -- positive fixnum
         table.insert( strary, tostr(n))
      elseif n < 256 then -- uint8
         table.insert(strary, tostr(0xcc,n))
      elseif n < 65536 then -- uint16
        strary_append_int16(n,0xcd)
      elseif n < 4294967296 then -- uint32
        strary_append_int32(n,0xce)
      else -- lua cannot handle uint64, so double
         strary_append_double(n)
      end
    else -- negative integer
      if n >= -32 then -- negative fixnum
         table.insert( strary, tostr( 0xe0 + ((n+256)%32)) )
      elseif n >= -128 then -- int8
         table.insert( strary, tostr(0xd0,byte_mod(n,0x100)))
      elseif n >= -32768 then -- int16
        strary_append_int16(n,0xd1)
      elseif n >= -2147483648 then -- int32
        strary_append_int32(n,0xd2)
      else -- lua cannot handle int64, so double
         strary_append_double(n)
      end
    end
  else -- floating point
     strary_append_double(n)
  end
end

packers.string = function(data)
  local n = #data
  if n < 32 then
     table.insert( strary, tostr( 0xa0+n ) )
  elseif n < 65536 then
    strary_append_int16(n,0xda)
  elseif n < 4294967296 then
    strary_append_int32(n,0xdb)
  else
    error("overflow")
  end
  table.insert( strary, data)
end

packers["function"] = function(data)
  error("unimplemented:function")
end

packers.userdata = function(data)
  error("unimplemented:userdata")
end

packers.thread = function(data)
  error("unimplemented:thread")
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
       table.insert( strary, tostr(0x80+ndata))
    elseif ndata < 65536 then
      strary_append_int16(ndata,0xde)
    elseif ndata < 4294967296 then
      strary_append_int32(ndata,0xdf)
    else
      error("overflow")
    end
    for k,v in pairs(data) do
      packers[type(k)](k)
      packers[type(v)](v)
    end
  else -- pack as array
    if nmax < 16 then
       table.insert( strary, tostr( 0x90+nmax ) )
    elseif nmax < 65536 then
      strary_append_int16(nmax,0xdc)
    elseif nmax < 4294967296 then
      strary_append_int32(nmax,0xdd)
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
    if n < 0x80 then return "fixnum_posi"
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

local unpack_number = function(offset,ntype,nlen)
  --                         print("unpack_number: ntype:", ntype, " nlen:", nlen, "ofs:",offset, "nstrbuf:",#strbuf )
  local b1,b2,b3,b4,b5,b6,b7,b8
  if nlen>=2 then
    b1,b2 = string.byte( strbuf, offset+1, offset+2 )
  end
  if nlen>=4 then
    b3,b4 = string.byte( strbuf, offset+3, offset+4 )
  end
  if nlen>=8 then
    b5,b6,b7,b8 = string.byte( strbuf, offset+5, offset+8 )
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
    local s = tostr(b8,b7,b6,b5,b4,b3,b2,b1)                            
    --                            print(" unpack_double: slen:", string.len(s), b1, b2, b3, b4, b5, b6, b7, b8 )
    double_decode_count = double_decode_count + 1
    local n = bytestodouble( s )
    return n
  else
    error("unpack_number: not impl:" .. ntype )
  end
end



local function unpacker_number(offset)
local obj_type = type_for( string.byte( strbuf, offset+1, offset+1 ) )
local nlen = types_len_map[obj_type]
local ntype
if (obj_type == "float") then
  error("float is not implemented")
else
  ntype = obj_type .. "_t"
end
--  print("unpacker_number:  ntype:", ntype , " nlen:", nlen )
return offset+nlen+1,unpack_number(offset+1,ntype,nlen)
end

local function unpack_map(offset,n)
  local r = {}
  local k,v
  for i=1,n do
    offset,k = unpackers.dynamic(offset)
    assert(offset)
    offset,v = unpackers.dynamic(offset)
    assert(offset)
    r[k] = v
  end
  return offset,r
end

local function unpack_array(offset,n)
  local r = {}
  for i=1,n do
    offset,r[i] = unpackers.dynamic(offset)
    assert(offset)
  end
  return offset,r
end

function unpackers.dynamic(offset)
  --  print("unpackers.dynamic: strbuf:", #strbuf, " ofs:", offset )
  if offset >= #strbuf then error("need more data") end
  local obj_type = type_for( string.byte( strbuf, offset+1, offset+1 ) )
  --   print("unpackers.dynamic: type:", obj_type, string.format(" typebyte:%x", buf[offset+1]))
  return unpackers[obj_type](offset)
end

function unpackers.undefined(offset)
   error("unimplemented:undefined")
end

unpackers["nil"] = function(offset)
  return offset+1,nil
end

unpackers["false"] = function(offset)
  return offset+1,false
end

unpackers["true"] = function(offset)
  return offset+1,true
end

unpackers.fixnum_posi = function(offset)
  return offset+1, string.byte( strbuf, offset+1, offset+1) 
end

unpackers.uint8 = function(offset)
  return offset+2, string.byte( strbuf, offset+2, offset+2 )
end

unpackers.uint16 = unpacker_number
unpackers.uint32 = unpacker_number
unpackers.uint64 = unpacker_number

unpackers.fixnum_neg = function(offset)
  -- alternative to cast below:
  local n = string.byte( strbuf, offset+1, offset+1)
  local nn = ( 256 - n ) * -1
  return offset+1,  nn
end

unpackers.int8 = function(offset)
  local i = string.byte( strbuf, offset+2, offset+2 )
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

unpackers.fixraw = function(offset)
  local n = byte_mod( string.byte( strbuf, offset+1, offset+1) ,0x1f+1)
  --  print("unpackers.fixraw: offset:", offset, "#buf:", #buf, "n:",n  )
  local b
  if ( #strbuf - 1 - offset ) < n then
    error("require more data")
  end  
  
  if n > 0 then
    b = string.sub( strbuf, offset + 1 + 1, offset + 1 + 1 + n - 1 )
  else
    b = ""
  end  
  return offset+n+1,b
end

unpackers.raw16 = function(offset)
  local n = unpack_number(offset+1,"uint16_t",2)
  if ( #strbuf - 1 - 2 - offset ) < n then
     error("require more data")
  end
  local b = string.sub( strbuf, offset+1+1+2, offset+1 + 1+2 + n - 1 )
  return offset+n+3,b 
end

unpackers.raw32 = function(offset)
  local n = unpack_number(offset+1,"uint32_t",4)
  if ( #strbuf  - 1 - 4 - offset ) < n then
    error( "require more data (possibly bug)")
  end  
  --  print("unpackers.raw32: n:", n, string.format("%x %x %x %x %x", buf[offset+1], buf[offset+2], buf[offset+3], buf[offset+4], buf[offset+5]) )
  local b = string.sub( strbuf, offset+1+ 1+4, offset+1 + 1+4 +n -1 )
  return offset+n+5,b
end

unpackers.fixarray = function(offset)
  return unpack_array( offset+1,byte_mod( string.byte( strbuf, offset+1,offset+1),0x0f+1))
end

unpackers.array16 = function(offset)
  return unpack_array(offset+3,unpack_number(offset+1,"uint16_t",2)) 
end

unpackers.array32 = function(offset)
  return unpack_array(offset+5,unpack_number(offset+1,"uint32_t",4))
end

unpackers.fixmap = function(offset)
  return unpack_map(offset+1,byte_mod( string.byte( strbuf, offset+1,offset+1),0x0f+1))
end

unpackers.map16 = function(offset)
  return unpack_map(offset+3,unpack_number(offset+1,"uint16_t",2))
end

unpackers.map32 = function(offset)
  return unpack_map(offset+5,unpack_number(offset+1,"uint32_t",4))
end

-- Main functions

local ljp_pack = function(data)
  strary={}
  packers.dynamic(data)
  local s = table.concat(strary,"")
  --                    print("strary len:", #strary, strary[1], s,  string.sub(s,1) )                    
  return s
end

local ljp_unpack = function(s,offset)
  if offset == nil then offset = 0 end
  if type(s) ~= "string" then return false,"invalid argument" end
  local data
  strbuf = s
  offset,data = unpackers.dynamic(offset)
  return offset,data
end

function ljp_stat()
  return {
    double_decode_count = double_decode_count,
    double_encode_count = double_encode_count
  }
end

msgpack = {
  pack = ljp_pack,
  unpack = ljp_unpack,
  stat = ljp_stat
}

return msgpack

