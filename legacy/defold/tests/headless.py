#!/usr/bin/env python3
"""Cross-VM headless Lua test runner (sandbox local; CI uses real lua5.4).

Usage:  uv run --with lupa python tests/headless.py [tests/run_tests.lua ...]
Runs each given Lua file (default tests/run_tests.lua) on Lua 5.4, 5.1 and
LuaJIT 2.1 via lupa. Exit 0 only if every file passes on every VM.
"""
import sys

FILES = sys.argv[1:] or ["tests/run_tests.lua"]
VMS = []
for mod, name in (("lupa.lua54", "lua5.4"), ("lupa.lua51", "lua5.1"),
                  ("lupa.luajit21", "luajit2.1")):
    try:
        VMS.append((name, __import__(mod, fromlist=["LuaRuntime"])))
    except ImportError:
        print(f"[skip] {name}: lupa module missing")

failed = False
for path in FILES:
    for name, mod in VMS:
        rt = mod.LuaRuntime()
        rt.execute('package.path="./?.lua;./?/init.lua;"..package.path')
        try:
            rt.execute(f'dofile("{path}")')
            print(f"[ok]   {path} on {name}")
        except Exception as e:
            failed = True
            msg = str(e).strip().splitlines()
            print(f"[FAIL] {path} on {name}: " + (msg[-1] if msg else "?"))
sys.exit(1 if failed else 0)
