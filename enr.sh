#!/usr/bin/env python3
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


# Version
__version__ = "0.1.0"

def generate_nginx_config(
    server_name: str,
    proxy_pass: str,
    port: int = 80,
    output_path: Union[str, Path] = "default.conf",
) -> None:
    """Generate nginx configuration file.

    Args:
        server_name: Domain name for the server
        proxy_pass: Upstream server URL
        port: Port to listen on (default: 80)
        output_path: Path to save the configuration file
    """
    # Nginx configuration template using string formatting
    nginx_template = """server {{
  server_name {server_name};
  listen {port};

  location / {{
    proxy_pass {proxy_pass};
    proxy_pass_header Host;
    proxy_intercept_errors on;
    error_page 301 302 307 = @handle_redirect;
    # recursive_error_pages on;
  }}

  location @handle_redirect {{
    set $saved_redirect_location '$upstream_http_location';
    proxy_pass $saved_redirect_location;
  }}
}}"""

    # Format the template with provided values
    config_content = nginx_template.format(
        server_name=server_name,
        proxy_pass=proxy_pass,
        port=port,
    )

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(config_content)


def build_docker_command(
    server_name: str,
    container_name: str,
    network: str,
    config_path: Path,
    proxy_pass: str = None,
    with_letsencrypt: bool = False,
) -> List[str]:
    """Build Docker run command list.

    Args:
        server_name: Domain name for the server
        container_name: Name for the Docker container
        network: Docker network name
        config_path: Path to the nginx configuration file
        proxy_pass: Upstream server URL to determine if Let's Encrypt is needed

    Returns:
        List of command arguments for Docker run
    """
    # Convert config_path to absolute path for Docker mount
    config_abs_path = config_path.absolute()

    # Build Docker run command
    cmd = [
        "docker",
        "run",
        "--network",
        network,
        "-e",
        f"VIRTUAL_HOST={server_name}",
    ]

    # Add Let's Encrypt environment variables if proxy_pass uses HTTPS or --with-letsencrypt is specified
    if (proxy_pass and proxy_pass.startswith("https://")) or with_letsencrypt:
        cmd.extend(
            [
                "-e",
                f"LETSENCRYPT_HOST={server_name}",
                "-e",
                f"LETSENCRYPT_EMAIL=443@{server_name}",
            ]
        )

    # Add host.docker.internal support if proxy_pass contains it
    if proxy_pass and "host.docker.internal" in proxy_pass:
        cmd.extend(
            [
                "--add-host",
                "host.docker.internal:host-gateway",
            ]
        )

    # Add remaining command parts
    cmd.extend(
        [
            "-v",
            f"{config_abs_path}:/etc/nginx/conf.d/default.conf",
            "--name",
            container_name,
            "-d",
            "--restart",
            "always",
            "nginx:alpine",
        ]
    )

    return cmd


def run_nginx_container(
    server_name: str,
    container_name: str,
    network: str = "nginx-proxy",
    config_path: Union[str, Path] = "default.conf",
    proxy_pass: str = None,
    with_letsencrypt: bool = False,
) -> None:
    """Run nginx Docker container with the generated configuration.

    Args:
        server_name: Domain name for the server (used as VIRTUAL_HOST)
        container_name: Name for the Docker container
        network: Docker network name
        config_path: Path to the nginx configuration file
        proxy_pass: Upstream server URL to determine if Let's Encrypt is needed
    """
    config_path = Path(config_path)

    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    # Build Docker command using shared function
    cmd = build_docker_command(
        server_name=server_name,
        container_name=container_name,
        network=network,
        config_path=config_path,
        proxy_pass=proxy_pass,
        with_letsencrypt=with_letsencrypt,
    )

    # Print Let's Encrypt message if needed
    if (proxy_pass and proxy_pass.startswith("https://")) or with_letsencrypt:
        print(f"🔒 Added Let's Encrypt SSL support for {server_name}")

    try:
        # Check if container already exists
        check_cmd = [
            "docker",
            "ps",
            "-a",
            "--filter",
            f"name={container_name}",
            "--format",
            "{{.Names}}",
        ]
        result = subprocess.run(check_cmd, capture_output=True, text=True, check=True)

        if container_name in result.stdout.strip():
            # Remove existing container
            print(f"🔄 Removing existing container: {container_name}")
            subprocess.run(["docker", "rm", "-f", container_name], check=True)

        # Run new container
        subprocess.run(cmd, check=True)

    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to run Docker container: {e}") from e
    except FileNotFoundError:
        raise RuntimeError(
            "Docker command not found. Please ensure Docker is installed "
            "and running."
        ) from None


def generate_docker_command_display(
    server_name: str,
    container_name: str,
    network: str,
    config_path: Path,
    proxy_pass: str,
    with_letsencrypt: bool = False,
) -> str:
    """Generate Docker run command string for display purposes.

    Args:
        server_name: Domain name for the server
        container_name: Name for the Docker container
        network: Docker network name
        config_path: Path to the nginx configuration file
        proxy_pass: Upstream server URL
        with_letsencrypt: Whether to include Let's Encrypt SSL variables

    Returns:
        Formatted Docker run command string
    """
    # Use shared function to build command
    cmd = build_docker_command(
        server_name=server_name,
        container_name=container_name,
        network=network,
        config_path=config_path,
        proxy_pass=proxy_pass,
        with_letsencrypt=with_letsencrypt,
    )

    # Format command for display
    formatted_cmd = " \\\n  ".join(cmd)
    return formatted_cmd


def main():
    """Generate nginx config and run Docker container."""
    parser = argparse.ArgumentParser(
        description="Generate nginx config and run Docker container.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s example.com http://<container_name>:3000\n"
            "  %(prog)s example.com http://host.docker.internal:8000 --port 3000\n"
            "  %(prog)s example.com http://host.docker.internal:8000 --with-letsencrypt\n"
            "  %(prog)s shop.example.com https://marketplace.example/seller/<seller_id>\n"
            "  %(prog)s example.com https://example.tilda.ws --container-name my-tilda-proxy\n"
            "  %(prog)s test.com http://localhost:5000 --dry-run "
            "--config-dir ./configs --force\n"
        ),
    )

    parser.add_argument(
        "server_name",
        help="Domain name for the server",
    )
    parser.add_argument(
        "proxy_pass",
        help="Upstream server URL (e.g., http://localhost:3000)",
    )
    parser.add_argument(
        "--port",
        "-p",
        type=int,
        default=80,
        help="Port to listen on (default: 80)",
    )
    parser.add_argument(
        "--container-name",
        "-n",
        help="Docker container name (defaults to server_name)",
    )
    parser.add_argument(
        "--network",
        default="nginx-proxy",
        help="Docker network name (default: nginx-proxy)",
    )
    parser.add_argument(
        "--config-dir",
        "-d",
        default=".",
        help="Directory to save nginx config (default: current directory)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate config only, don't run Docker container",
    )
    parser.add_argument(
        "--force",
        "-f",
        action="store_true",
        help="Force overwrite existing config file",
    )
    parser.add_argument(
        "--with-letsencrypt",
        action="store_true",
        help="Automatically add Let's Encrypt environment variables for SSL support",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"ENR {__version__}",
        help="Show version and exit",
    )

    args = parser.parse_args()

    try:
        # Use server_name as container name if not specified
        if not args.container_name:
            args.container_name = args.server_name

        # Auto-add http:// protocol to proxy_pass if not specified
        proxy_pass = args.proxy_pass
        if not proxy_pass.startswith(("http://", "https://")):
            proxy_pass = f"http://{proxy_pass}"
            print(f"ℹ️  Auto-added http:// to proxy_pass: {proxy_pass}")

        # Validate config directory
        config_dir = Path(args.config_dir)
        if not config_dir.exists():
            print(
                f"Error: Config directory {config_dir} does not exist.",
                file=sys.stderr,
            )
            sys.exit(1)
        if not config_dir.is_dir():
            print(f"Error: {config_dir} is not a directory.", file=sys.stderr)
            sys.exit(1)

        # Generate nginx config
        config_path = config_dir / f"{args.server_name}.proxy.conf"

        if config_path.exists() and not args.force:
            print(
                (
                    f"Error: Config file {config_path} already exists. "
                    "Use --force to overwrite."
                ),
                file=sys.stderr,
            )
            sys.exit(1)

        generate_nginx_config(
            server_name=args.server_name,
            proxy_pass=proxy_pass,
            port=args.port,
            output_path=config_path,
        )

        print(f"✅ Generated nginx config: {config_path}")

        if args.dry_run:
            print("🔍 Dry run mode - Docker container not started")
            print()

            # Show generated config content
            print("📄 Generated nginx configuration:")
            print("=" * 50)
            with open(config_path) as f:
                print(f.read())
            print("=" * 50)

            # Show Docker command that would be executed
            print("\n🐳 Docker command that would be executed:")
            print("=" * 50)
            docker_cmd = generate_docker_command_display(
                server_name=args.server_name,
                container_name=args.container_name,
                network=args.network,
                config_path=config_path,
                proxy_pass=proxy_pass,
                with_letsencrypt=args.with_letsencrypt,
            )
            print(docker_cmd)
            print("=" * 50)

            if proxy_pass.startswith("https://") or args.with_letsencrypt:
                print(
                    "\n🔒 Note: Let's Encrypt SSL variables will be added "
                    "for HTTPS proxy_pass or --with-letsencrypt option"
                )

            return

        # Run Docker container
        run_nginx_container(
            server_name=args.server_name,
            container_name=args.container_name,
            network=args.network,
            config_path=config_path,
            proxy_pass=proxy_pass,
            with_letsencrypt=args.with_letsencrypt,
        )

        print(f"✅ Started nginx container: {args.container_name}")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)



if __name__ == "__main__":
    main()
