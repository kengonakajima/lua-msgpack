# lua-msgpack

## Presentation

This is a simple implementation of MessagePack for Lua.

It runs almost same as:
[luajit-msgpack](https://github.com/catwell/luajit-msgpack),
[luajit-msgpack-pure](https://github.com/catwell/luajit-msgpack-pure),
but it doesn't require LuaJIT and FFI. Only requires Lua 5.1 runtime.

## Why
Now [Moai SDK](https://github.com/moai/moai-dev) isn't based on LuaJIT so I had to delete dependencies on LuaJIT.
Special thanks to luajit-msgpack-pure! Nice tests.

Since it's not using fast C-based binary buffer,
it runs about 20x slower than luajit-msgpack-pure.
But it's totally enough for client-side game dev.


## Limitations
Currently int64, uint64, float, double types are not implemented.


## TODO

- int64, uint64, float, double
- Omit luabit(bit.lua) and switch to embedded bitwise ops after Moai SDK supports Lua 5.2.

## Usage

See tests/test.lua for usage.

