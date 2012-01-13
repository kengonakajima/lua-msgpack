# lua-msgpack

<a href="http://travis-ci.org/kengonakajima/lua-msgpack"><img src="https://secure.travis-ci.org/kengonakajima/lua-msgpack.png"></a>


This is a simple implementation of [MessagePack](http://msgpack.org/) for Lua.

MessagePack is a very simple and powerful serialization format for many platforms and languages.

lua-msgpack runs almost same as:
[luajit-msgpack](https://github.com/catwell/luajit-msgpack),
[luajit-msgpack-pure](https://github.com/catwell/luajit-msgpack-pure),
but it doesn't require LuaJIT and FFI, nor any native libs. Only requires Lua 5.1 runtime.

## Why
Now [Moai SDK](https://github.com/moai/moai-dev) isn't based on LuaJIT so I had to delete dependencies on LuaJIT.
Special thanks to luajit-msgpack-pure! Tests are almost same as its.

## Usage

In your app:

    local mp = require( "msgpack" )
    local tbl = { a=123, b="any", c={"ta","bl","e",1,2,3} }
    local packed = mp.pack(tbl)
    local unpacked_table = mp.unpack(packed)

On Moai and Lua5.1, put luabit.lua and msgpack.lua in your project directory.
On LuaJIT, you need only msgpack.lua.

    
## Compatibility
Tested on lua5.1, luajit2-beta8, Moai beta 0.8

## Limitations
- Currently int64, uint64, float types are not implemented. these types are converted into double.

- Performance. It runs about 20x ~ 1000x slower than luajit-msgpack-pure,
so don't usable for server side, but it's totally enough for client-side game dev.

For details, try bench.lua for benchmarking:

luajit2:

    empty     8.59e-05	sec	348837.20930233	times/sec
    iary1     0.000232	sec	129310.34482759	times/sec
    iary10    0.00074	sec	40540.54054054	times/sec
    iary100   0.001886	sec	15906.680805939	times/sec
    iary1000  0.091806	sec	326.77602771061	times/sec
    iary10000 3.767413	sec	7.9630239636589	times/sec
    str1      0.00039	sec	75376.884422088	times/sec
    str10     0.00027	sec	107526.88172046	times/sec
    str100    0.00174	sec	17162.47139588	times/sec
    str1000	  0.028931	sec	1036.9499844457	times/sec
    str10000  0.913015	sec	32.858167719041	times/sec

lua 5.1 (moai):

    empty     0.001068	sec	28089.887640449	times/sec
    iary1     0.00179	sec	16759.776536313	times/sec
    iary10    0.005115	sec	5865.1026392962	times/sec
    iary100   0.057657	sec	520.31843488215	times/sec
    iary1000  3.425564	sec	8.7576819466809	times/sec
    iary10000 50.159382	sec	0.5980934932571	times/sec
    str1      0.002448	sec	12249.897917524	times/sec
    str10     0.005663	sec	5297.5454705935	times/sec
    str100    0.047862	sec	626.80205591072	times/sec
    str1000   0.411015	sec	72.990036859969	times/sec
    str10000  4.713626	sec	6.3645270116891	times/sec

on mac book pro i5 2.53GHz.


## TODO
- int64, uint64, float



