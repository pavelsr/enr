#!/usr/bin/env python3
"""CLI interface for ENR utility."""

import argparse
import sys
from pathlib import Path

from . import __version__
from .docker import build_docker_command, run_nginx_container
from .nginx import generate_nginx_config


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
