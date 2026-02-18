#!/usr/bin/env bash

set -euo pipefail

IRONFRAME_VERSION="0.3.1"
PROJECT_ROOT="${DEVBOX_PROJECT_ROOT:-$(pwd)}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
PLATFORM_KEY="${OS}-${ARCH}"

INSTALL_ROOT="${PROJECT_ROOT}/.devbox/ironframe/${PLATFORM_KEY}"
IRONFRAME_BIN="${INSTALL_ROOT}/bin/ironframe"
VERSION_FILE="${INSTALL_ROOT}/.ironframe-version"

export CARGO_HOME="${CARGO_HOME:-${PROJECT_ROOT}/.devbox/cargo}"
export PATH="${INSTALL_ROOT}/bin:${PATH}"

# Some devbox environments expose package binaries only via HOST_PATH.
# Merge it so cargo/rustc are resolvable when running via `devbox run`.
if ! command -v cargo >/dev/null 2>&1 && [ -n "${HOST_PATH:-}" ]; then
  export PATH="${HOST_PATH}:${PATH}"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo command not found. Ensure Rust toolchain is available in devbox." >&2
  echo "Try: devbox install && devbox run -- cargo --version" >&2
  exit 127
fi

current_version=""
if [ -f "${VERSION_FILE}" ]; then
  current_version="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi

if [ ! -x "${IRONFRAME_BIN}" ] || [ "${current_version}" != "${IRONFRAME_VERSION}" ]; then
  echo "Installing ironframe ${IRONFRAME_VERSION} for ${PLATFORM_KEY}..."
  mkdir -p "${INSTALL_ROOT}" "${CARGO_HOME}"
  cargo install ironframe --version "${IRONFRAME_VERSION}" --locked --force --root "${INSTALL_ROOT}"
  printf '%s\n' "${IRONFRAME_VERSION}" > "${VERSION_FILE}"
fi

exec "${IRONFRAME_BIN}" "$@"
