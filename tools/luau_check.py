"""Syntax-checks Luau files by compiling them in Roblox Studio (loadstring in the Edit DataModel;
nothing runs). Talks to StudioMCP.exe directly, like blender/tools/dump_map.py, so Studio must be
open. Usage: python tools/luau_check.py <file.lua> [...]   (paths relative to the repo or absolute)
"""
import glob
import json
import os
import subprocess
import sys
import time

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def studio_mcp():
    exes = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))
    return max(exes, key=os.path.getmtime)


def long_string(src):
    level = 1
    while ("]" + "=" * level + "]") in src:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + src + "]" + eq + "]"


def main(files):
    p = subprocess.Popen([studio_mcp()], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
    n = [0]

    def call(method, params=None, notify=False):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            n[0] += 1
            msg["id"] = n[0]
        p.stdin.write(json.dumps(msg) + "\n")
        p.stdin.flush()
        if notify:
            return None
        while True:
            r = json.loads(p.stdout.readline())
            if r.get("id") == n[0]:
                return r

    call("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "luau_check", "version": "1"}})
    call("notifications/initialized", notify=True)
    time.sleep(8)  # the proxy takes a few seconds to find Studio
    sid = None
    for _ in range(10):
        st = json.loads(call("tools/call", {"name": "list_roblox_studios", "arguments": {}})["result"]["content"][0]["text"])["studios"]
        st = [x for x in st if x.get("name")] or st  # (a Studio with no place open has no name)
        if st:
            sid = st[0]["id"]
            break
        time.sleep(3)
    if not sid:
        p.kill()
        sys.exit("no studio")
    bad = 0
    for path in files:
        full = path if os.path.isabs(path) else os.path.join(REPO, path)
        src = open(full, encoding="utf-8").read()
        code = "local f, e = loadstring(%s, %s) return f and 'OK' or e" % (long_string(src), json.dumps(os.path.basename(full)))
        r = call("tools/call", {"name": "execute_luau", "arguments": {"studio_id": sid, "datamodel_type": "Edit", "code": code}})
        txt = "".join(c.get("text", "") for c in r.get("result", {}).get("content", []))
        ok = txt.strip() == "OK"
        bad += not ok
        print(("ok    " if ok else "ERROR ") + os.path.relpath(full, REPO) + ("" if ok else "\n      " + txt.strip()), flush=True)
    p.kill()
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
