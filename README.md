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

<pre>
empty	0.0029920000000001	sec	1671122.9946523	times/sec
iary1	0.006181	sec	808930.59375506	times/sec
iary10	0.024651	sec	202831.52813273	times/sec
iary100	0.019591	sec	25521.923332142	times/sec
iary1000	0.027691	sec	1805.6408219277	times/sec
iary10000	0.038497	sec	129.88025040912	times/sec
dary1	0.001633	sec	61236.987140233	times/sec
dary10	0.0049349999999999	sec	10131.712259372	times/sec
dary100	0.0066330000000001	sec	753.80672395597	times/sec
dary1000	0.053496	sec	93.46493195753	times/sec
str1	0.011589	sec	431443.61032013	times/sec
str10	0.008448	sec	591856.06060606	times/sec
str100	0.014457	sec	345853.21989348	times/sec
str1000	0.014576	sec	343029.6377607	times/sec
str10000	0.0046630000000001	sec	107227.10701265	times/sec
str20000	0.0087540000000002	sec	57116.746630111	times/sec
str30000	0.012676	sec	39444.619753866	times/sec
str40000	0.002127	sec	23507.28725905	times/sec
str80000	0.0042070000000001	sec	11884.953648681	times/sec
</pre>

moai sdk:

<pre>
empty	0.019725	sec	253485.42458808	times/sec
iary1	0.034026	sec	146946.45271263	times/sec
iary10	0.15399	sec	32469.640885772	times/sec
iary100	0.117005	sec	4273.3216529208	times/sec
iary1000	0.147932	sec	337.99313197956	times/sec
iary10000	0.198838	sec	25.146098834227	times/sec
dary1	0.272365	sec	367.15437005489	times/sec
dary10	1.207196	sec	41.418294957902	times/sec
dary100	1.230383	sec	4.0637752634749	times/sec
dary1000	12.397338	sec	0.40331238851437	times/sec
str1	0.054717	sec	91379.278834731	times/sec
str10	0.044854000000001	sec	111472.77834753	times/sec
str100	0.053418999999998	sec	93599.655553271	times/sec
str1000	0.048525999999999	sec	103037.54688209	times/sec
str10000	0.0071469999999998	sec	69959.423534352	times/sec
str20000	0.010031999999999	sec	49840.510366831	times/sec
str30000	0.0091239999999999	sec	54800.526085051	times/sec
str40000	0.0011280000000014	sec	44326.241134699	times/sec
str80000	0.0017399999999981	sec	28735.63218394	times/sec
</pre>

on mac book pro i5 2.53GHz.


## TODO
- int64, uint64, float



## License
Apache License 2.0. see LICENSE.txt.
