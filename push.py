"""Push local src/ (Rojo naming) into the open Roblox Studio place via the Studio MCP.
usage: python push.py [path-prefix ...]   (no args = push everything)"""
import json,subprocess,sys,time,os,re
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),"src")
import glob,os as _os
exe=max(glob.glob(_os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe")),key=_os.path.getmtime)  # the newest Studio install
files=[]
for d,_,fs in os.walk(ROOT):
    for f in fs:
        if not f.endswith(".lua"): continue
        rel=os.path.relpath(os.path.join(d,f),ROOT).replace("\\","/")
        if len(sys.argv)>1 and not any(rel.startswith(a) for a in sys.argv[1:]): continue
        files.append(rel)
def cls(name):
    if name.endswith(".server.lua"): return name[:-11],"Script"
    if name.endswith(".client.lua"): return name[:-11],"LocalScript"
    return name[:-4],"ModuleScript"
def longstr(s):
    n=0
    while ("]"+"="*n+"]") in s: n+=1
    return "["+"="*n+"["+s+"]"+"="*n+"]"
parts=["""local function dir(p,n) local c=p:FindFirstChild(n) if not c then c=Instance.new("Folder") c.Name=n c.Parent=p end return c end
local function file(p,n,k,src) local c=p:FindFirstChild(n) if c and c.ClassName~=k then c:Destroy() c=nil end
 if not c then c=Instance.new(k) c.Name=n c.Parent=p end c.Source=src return c end
local out={}"""]
for rel in sorted(files):
    segs=rel.split("/"); name,k=cls(segs[-1])
    expr=f'game:GetService("{segs[0]}")'
    for s in segs[1:-1]: expr=f'dir({expr},"{s}")'
    src=open(os.path.join(ROOT,rel),encoding="utf-8").read()
    parts.append(f'file({expr},"{name}","{k}",{longstr(src)}) table.insert(out,"{rel}")')
parts.append('return "pushed "..#out..": "..table.concat(out,", ")')
code="\n".join(parts)
p=subprocess.Popen([exe],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,encoding='utf-8')
def send(m): p.stdin.write(json.dumps(m)+"\n"); p.stdin.flush()
def recv(i):
    while True:
        r=json.loads(p.stdout.readline())
        if r.get("id")==i: return r
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"push","version":"1"}}}); recv(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"}); time.sleep(8)
send({"jsonrpc":"2.0","id":2,"method":"tools/list"}); recv(2)
sid=None
for attempt in range(10):
    send({"jsonrpc":"2.0","id":100+attempt,"method":"tools/call","params":{"name":"list_roblox_studios","arguments":{}}})
    studios=json.loads(recv(100+attempt)["result"]["content"][0]["text"])["studios"]
    named=[s for s in studios if s.get("name")]  # (a Studio with no place open shows up with no name)
    if named or studios: sid=(named or studios)[0]["id"]; break
    time.sleep(3)
if not sid: sys.exit("No Roblox Studio connected - is the place open with the MCP plugin enabled?")
send({"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"execute_luau","arguments":{"studio_id":sid,"datamodel_type":"Edit","code":code}}})
r=recv(4); sys.stdout.reconfigure(encoding="utf-8")
for c in r.get("result",{}).get("content",[]): print(c.get("text",""))
p.kill()
