# rea-docker

[![version)](https://img.shields.io/docker/v/crashvb/rea/latest)](https://hub.docker.com/repository/docker/crashvb/rea)
[![image size](https://img.shields.io/docker/image-size/crashvb/rea/latest)](https://hub.docker.com/repository/docker/crashvb/rea)
[![linting](https://img.shields.io/badge/linting-hadolint-yellow)](https://github.com/hadolint/hadolint)
[![license](https://img.shields.io/github/license/crashvb/rea-docker.svg)](https://github.com/crashvb/rea-docker/blob/master/LICENSE.md)

## Overview

This docker image contains [REA](https://github.com/morluto/rea) and serves its MCP catalog over Streamable HTTP. OpenJDK, [Ghidra](https://github.com/NationalSecurityAgency/ghidra), [Hopper](https://www.hopperapp.com/), and [Kuna](https://github.com/Noelo-Lab/kuna) are included for native analysis.

The image builds REA from a pinned upstream source revision because Streamable HTTP support is newer than the current published npm package. Node.js and npm remain available in the runtime image; rebuild the image to make production upgrades reproducible.

REA's HTTP endpoint uses plain HTTP without client authentication. Publish it only on a trusted network or place it behind a TLS and authentication proxy.

Ghidra is the default analysis provider. Select another configured provider with `REA_ANALYSIS_PROVIDER` or `open_binary.provider_id`.

## Entrypoint Scripts

### rea

The embedded entrypoint script is located at `/etc/entrypoint.d/rea` and performs the following actions:

1. The REA state and Kuna cache directories are initialized with service-user ownership.
2. The bundled Hopper launcher is detected at `/opt/hopper/bin/Hopper`.
3. A mounted IDA MCP registration is detected at `/etc/rea/ida-mcp.json`.

The following environment variables configure the service:

| Variable | Default Value | Description |
| -------- | ------------- | ----------- |
| MCP\_HOST | 0.0.0.0 | MCP listener address. |
| MCP\_PORT | 8765 | MCP listener port. |
| GHIDRA\_INSTALL\_DIR | /opt/ghidra | Bundled Ghidra installation. |
| HOPPER\_LAUNCHER\_PATH | /opt/hopper/bin/Hopper | Bundled Hopper launcher. |
| REA\_ANALYSIS\_PROVIDER | ghidra | Default native-analysis provider. |
| REA\_HOME | /var/lib/rea | Home and persistent state directory for the REA service user. |
| REA\_IDA\_MCP\_CONFIG | | IDA MCP registration; automatically set for `/etc/rea/ida-mcp.json`. |
| REA\_KUNA\_CACHE\_DIR | /var/lib/rea/cache/kuna | Kuna specification and project cache. |
| REA\_KUNA\_COMMAND | /usr/local/bin/kuna | Bundled Kuna executable. |

## Analysis Providers

### Ghidra

Ghidra 12.1.4 and the full OpenJDK 21 are included. REA runs Ghidra headlessly; neither a display nor a GPU is required.

### Kuna

Kuna 1.833 is included. This is the version verified by the pinned REA revision. Select it explicitly with `REA_ANALYSIS_PROVIDER=kuna` or `provider_id: "kuna"`.

### Hopper

Hopper 6.6.0 for Linux is included from Hopper's public installer. Its license still governs use of the installed application. Xvfb supplies the display required by the Hopper bridge; a GPU is not required. Select it with `REA_ANALYSIS_PROVIDER=hopper` or `provider_id: "hopper"`.

### IDA

Mount an existing REA-compatible IDA MCP registration at `/etc/rea/ida-mcp.json`; the entrypoint detects it automatically:

```shell
docker run --volume=/path/to/ida-mcp.json:/etc/rea/ida-mcp.json:ro ... crashvb/rea
```

The commands and paths referenced by the registration must be accessible inside the container. An attached native IDA MCP endpoint can instead be used with an appropriate container network configuration.

## Standard Configuration

### Container Layout

```
/
├─ etc/
│  ├─ entrypoint.d/
│  │  └─ rea
│  ├─ healthcheck.d/
│  │  └─ rea
│  ├─ rea/
│  │  └─ ida-mcp.json (optional bind mount)
│  └─ supervisor/
│     └─ config.d/
│        └─ rea.conf
├─ opt/
│  ├─ ghidra/
│  └─ hopper/
├─ usr/
│  └─ local/
│     └─ bin/
│        └─ kuna
└─ var/
   └─ lib/
      └─ rea/
```

### Exposed Ports

* `8765/tcp` - REA Streamable HTTP MCP endpoint at `/mcp`.

### Volumes

* `/var/lib/rea` - REA service-user home and persistent state directory.

Mount analysis targets separately, preferably read-only, and pass their container paths to REA.

## Development

[Source Control](https://github.com/crashvb/rea-docker)
