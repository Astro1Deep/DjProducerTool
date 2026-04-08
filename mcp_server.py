#!/usr/bin/env python3
"""Compatibility wrapper for MCP server entrypoint.

Historically this module required native `mcp` package.
Now it routes to the hardened fixed server to keep the CLI and tests stable.
"""

from core.mcp_server_fixed import *  # noqa: F401,F403


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
