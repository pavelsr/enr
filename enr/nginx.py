"""Nginx configuration generation module."""

from pathlib import Path
from typing import Union


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
