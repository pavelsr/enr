#!/usr/bin/env python3
"""Build single script from modules.

This script combines all modules into a single executable script.
"""

import os
from pathlib import Path


def read_file_content(file_path: Path) -> str:
    """Read file content and return it as string."""
    with open(file_path, encoding="utf-8") as f:
        return f.read()


def extract_functions_from_module(module_content: str, module_name: str) -> str:
    """Extract functions from module content, removing imports and main function."""
    lines = module_content.split("\n")
    result_lines = []

    # Skip shebang, docstring, and imports
    skip_until_function = True
    in_docstring = False

    for line in lines:
        # Skip shebang
        if line.startswith("#!/"):
            continue

        # Skip module docstring
        if skip_until_function and (line.startswith('"""') or line.startswith("'''")):
            if '"""' in line or "'''" in line:
                # Single line docstring
                continue
            else:
                # Multi-line docstring
                in_docstring = True
                continue

        if skip_until_function and in_docstring:
            if '"""' in line or "'''" in line:
                in_docstring = False
            continue

        # Skip imports
        if skip_until_function and (
            line.startswith("import ") or line.startswith("from ")
        ):
            continue

        # Skip empty lines after imports
        if skip_until_function and line.strip() == "":
            continue

        # Start collecting from first function
        if skip_until_function and line.strip().startswith("def "):
            skip_until_function = False

        # Skip main function and if __name__ == "__main__"
        if line.strip() == 'if __name__ == "__main__":':
            break

        if not skip_until_function:
            result_lines.append(line)

    return "\n".join(result_lines)


def build_single_script():
    """Build single script from modules."""
    # Script header
    header = '''#!/usr/bin/env python3
"""ENR - Nginx Reverse Proxy CLI - Single File Script

CLI utility for generating nginx configuration and running Docker containers with nginx reverse proxy.
Uses only Python standard library without external dependencies.

Installation:
curl -fsSL --compressed https://raw.githubusercontent.com/pavelsr/enr/main/enr.sh > /usr/local/bin/enr && chmod +x /usr/local/bin/enr

Usage:
enr example.com http://localhost:3000
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Union, List

'''

    # Read module contents
    init_content = read_file_content(Path("enr/__init__.py"))
    nginx_content = read_file_content(Path("enr/nginx.py"))
    docker_content = read_file_content(Path("enr/docker.py"))
    cli_content = read_file_content(Path("enr/cli.py"))

    # Extract version from __init__.py
    version_line = None
    for line in init_content.split("\n"):
        if line.startswith("__version__"):
            version_line = line
            break

    # Extract functions from modules
    nginx_functions = extract_functions_from_module(nginx_content, "nginx")
    docker_functions = extract_functions_from_module(docker_content, "docker")
    cli_functions = extract_functions_from_module(cli_content, "cli")

    # Combine everything
    single_script = (
        header
        + "\n# Version\n"
        + version_line
        + "\n\n"
        + nginx_functions
        + "\n\n"
        + docker_functions
        + "\n\n"
        + cli_functions
        + '\n\nif __name__ == "__main__":\n    main()\n'
    )

    # Write to file
    output_path = Path("enr.sh")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(single_script)

    # Make executable
    os.chmod(output_path, 0o755)

    print(f"✅ Built single script: {output_path}")
    print(f"📏 Size: {output_path.stat().st_size} bytes")


if __name__ == "__main__":
    build_single_script()
