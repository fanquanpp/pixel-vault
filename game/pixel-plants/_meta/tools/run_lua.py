"""Run a Lua file through the Aseprite MCP's run_lua_script tool.

Usage: python run_lua.py <script.lua> [--timeout 600]
"""
import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_call import params  # noqa: E402

from mcp import ClientSession  # noqa: E402
from mcp.client.stdio import stdio_client  # noqa: E402


async def main(path):
    with open(path, "r", encoding="utf-8") as f:
        script = f.read()
    async with stdio_client(params()) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            res = await session.call_tool("run_lua_script", {"script": script})
            for blk in res.content:
                txt = getattr(blk, "text", None)
                if txt is not None:
                    print(txt)
            print("isError:", getattr(res, "isError", None))


asyncio.run(main(sys.argv[1]))
