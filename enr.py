#!/usr/bin/env python3
"""ENR CLI utility - simple launcher script."""

import sys
from pathlib import Path

from enr.cli import main

# Add the enr package to Python path
sys.path.insert(0, str(Path(__file__).parent))

if __name__ == "__main__":
    main()
