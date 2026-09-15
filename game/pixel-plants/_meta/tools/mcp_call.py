"""Drive the Aseprite MCP server over stdio.

Usage:
    python mcp_call.py list
    python mcp_call.py call <tool> '<json-args>'
    python mcp_call.py batch <calls.json>      # calls.json = [{"tool":..,"args":{..}}, ...]
    python mcp_call.py batchfile <file>        # reads a "CallName<TAB>jsonargs" lines file

Runs the real server at C:\\Atian\\aseprite-mcp via `python -m aseprite_mcp`.
"""
import asyncio
import json
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER_DIR = r"C:\Atian\aseprite-mcp"
PY = os.path.join(SERVER_DIR, ".venv", "Scripts", "python.exe")
ASEPRITE = r"C:\Atian\Aseprite\aseprite.exe"


def params():
    env = dict(os.environ)
    env["ASEPRITE_PATH"] = ASEPRITE
    env["PYTHONPATH"] = SERVER_DIR
    env["PYTHONIOENCODING"] = "utf-8"
    return StdioServerParameters(
        command=PY, args=["-m", "aseprite_mcp"], env=env, cwd=SERVER_DIR
    )


async def run(calls, do_list=False):
    async with stdio_client(params()) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            if do_list:
                tl = await session.list_tools()
                print("TOOL COUNT:", len(tl.tools))
                for t in tl.tools:
                    print("---", t.name)
                    print("   ", (t.description or "").splitlines()[0] if t.description else "")
                return
            for c in calls:
                tool = c["tool"]
                args = c.get("args", {})
                try:
                    res = await session.call_tool(tool, args)
                    parts = []
                    for blk in res.content:
                        txt = getattr(blk, "text", None)
                        if txt is not None:
                            parts.append(txt)
                    out = "\n".join(parts)
                    print(f"=== {tool} -> isError={getattr(res,'isError',None)}")
                    print(out)
                except Exception as e:  # noqa: BLE001
                    print(f"=== {tool} -> EXCEPTION {type(e).__name__}: {e}")


def main():
    argv = sys.argv[1:]
    if not argv:
        print("usage: list | call <tool> <json> | batch <jsonfile>")
        return 2
    if argv[0] == "list":
        asyncio.run(run([], do_list=True))
        return 0
    if argv[0] == "call":
        calls = [{"tool": argv[1], "args": json.loads(argv[2]) if len(argv) > 2 else {}}]
        asyncio.run(run(calls))
        return 0
    if argv[0] == "batch":
        with open(argv[1], "r", encoding="utf-8") as f:
            calls = json.load(f)
        asyncio.run(run(calls))
        return 0
    print("unknown command", argv[0])
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
