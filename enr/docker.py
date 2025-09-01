"""Docker container management module."""

import subprocess
from pathlib import Path
from typing import List, Union


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
