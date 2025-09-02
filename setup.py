#!/usr/bin/env python3
"""Setup script for ENR package."""

import sys
from pathlib import Path

# Add the project root to the path to import version
sys.path.insert(0, str(Path(__file__).parent))

try:
    from enr import __version__
except ImportError:
    __version__ = "unknown"

# This project uses flit for building
# This file is kept for compatibility with tools that expect setup.py
if __name__ == "__main__":
    print("This project uses flit for building. Use 'flit build' or 'make build-dist'")
    print(f"Current version: {__version__}")
