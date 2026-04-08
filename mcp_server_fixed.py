#!/usr/bin/env python3
"""Compatibility wrapper for the MCP fixed server.

Keeps legacy imports working:
  - from mcp_server_fixed import app
  - python mcp_server_fixed.py
"""

from core.mcp_server_fixed import *  # noqa: F401,F403


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
