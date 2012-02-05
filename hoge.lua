luabit= require "./luabit"


function doit(a,b)
   print(a,b,luabit.brshift(a,b))
end
doit(0,1)
doit(1,1)
doit(2,1)
doit(-1,1)
doit(-2,1)
doit(-4,1)
doit(-8,1)
doit(-16,1)
doit(-1024,1)


function int16to2byte(n)
	if n < 0 then
       n = n + 65536
    end
    return math.floor(n / 256), n % 256
 end
print("----------")
print(0, int16to2byte( 0))
print(1, int16to2byte( 1))
print(254, int16to2byte(254))
print(255, int16to2byte(255))
print(-1, int16to2byte(-1))
print(-2, int16to2byte(-2))

print("---------")

function orit(a,b)
   print(a,b, luabit.bor(a,b) % 256 )
end

orit(0xf0,0x1)
orit(0xe0,-1)
orit(0xe0,-15)


-- make 8bit with [0x high4 low4]
function bit_4_4_or(high4,low4)
   return high4*16 + low
end

