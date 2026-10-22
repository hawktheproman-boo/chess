"""Runs a Luau file in Roblox Studio and prints what it returns (builders, checks).
Usage: python tools/run_luau.py <file.lua> [Edit|Server|Client]   (default Edit)
Talks to StudioMCP.exe directly, like luau_check.py, so Studio must be open with the place.
"""
import glob
import json
import os
import subprocess
import sys
import time

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main(path, dm="Edit"):
    exe = max(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe")), key=os.path.getmtime)
    p = subprocess.Popen([exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         text=True, encoding="utf-8")
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

    call("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "run_luau", "version": "1"}})
    call("notifications/initialized", notify=True)
    time.sleep(8)  # the proxy takes a few seconds to find Studio
    sid = None
    for _ in range(10):
        st = json.loads(call("tools/call", {"name": "list_roblox_studios", "arguments": {}})["result"]["content"][0]["text"])["studios"]
        st = [x for x in st if x.get("name")] or st
        if st:
            sid = st[0]["id"]
            break
        time.sleep(3)
    if not sid:
        p.kill()
        sys.exit("no studio")
    full = path if os.path.isabs(path) else os.path.join(REPO, path)
    code = open(full, encoding="utf-8").read()
    r = call("tools/call", {"name": "execute_luau", "arguments": {"studio_id": sid, "datamodel_type": dm, "code": code}})
    sys.stdout.reconfigure(encoding="utf-8")
    print("".join(c.get("text", "") for c in r.get("result", {}).get("content", [])))
    p.kill()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "Edit")
