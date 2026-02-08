#!/usr/bin/env bash

set -euo pipefail

IRONFRAME_VERSION="0.3.1"
PROJECT_ROOT="${DEVBOX_PROJECT_ROOT:-$(pwd)}"
INSTALL_ROOT="${PROJECT_ROOT}/.devbox"
IRONFRAME_BIN="${INSTALL_ROOT}/bin/ironframe"

export CARGO_HOME="${CARGO_HOME:-${PROJECT_ROOT}/.devbox/cargo}"
export PATH="${INSTALL_ROOT}/bin:${PATH}"

current_version=""
if [ -x "${IRONFRAME_BIN}" ]; then
  current_version="$("${IRONFRAME_BIN}" --version 2>/dev/null | sed -nE 's/.* ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n1)"
elif command -v ironframe >/dev/null 2>&1; then
  current_version="$(ironframe --version 2>/dev/null | sed -nE 's/.* ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n1)"
fi

if [ "${current_version}" != "${IRONFRAME_VERSION}" ]; then
  echo "Installing ironframe ${IRONFRAME_VERSION}..."
  mkdir -p "${INSTALL_ROOT}" "${CARGO_HOME}"
  cargo install ironframe --version "${IRONFRAME_VERSION}" --locked --force --root "${INSTALL_ROOT}"
fi

exec "${IRONFRAME_BIN}" "$@"
