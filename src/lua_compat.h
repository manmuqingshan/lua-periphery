#ifndef _LUA_COMPAT_H
#define _LUA_COMPAT_H

#if LUA_VERSION_NUM == 501
#define luaL_len(L, idx) (lua_objlen(L, idx))
#endif

#if LUA_VERSION_NUM == 501 || LUA_VERSION_NUM == 502
/* Lua 5.1 and 5.2 don't have a native integer type, so we stick with lua_Number. */
#define lua_tolargeinteger(L, idx) (lua_tonumber(L, idx))
#define lua_pushlargeinteger(L, val) (lua_pushnumber(L, (lua_Number)val))
#define luaL_checklargeinteger(L, narg) (luaL_checknumber(L, narg))
#define LUA_MAXINTEGER 9007199254740991 /* 2**53 - 1 */
#elif LUA_VERSION_NUM >= 503
/* Lua 5.3 and 5.4 have native integer types with 63-bits unsigned range (typically).
 * We check LUA_MAXINTEGER before pushing large numbers onto the stack. */
#define lua_tolargeinteger(L, idx) (lua_tointeger(L, idx))
#define lua_pushlargeinteger(L, val) (lua_pushinteger(L, val))
#define luaL_checklargeinteger(L, narg) (luaL_checkinteger(L, narg))
#endif

#endif

