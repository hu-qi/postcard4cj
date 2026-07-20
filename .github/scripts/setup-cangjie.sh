#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANGJIE_VERSION="${CANGJIE_VERSION:-1.1.3}"
CANGJIE_PLATFORM="${CANGJIE_PLATFORM:-linux-x64}"
SDK_FILE="cangjie-sdk-${CANGJIE_PLATFORM}-${CANGJIE_VERSION}.tar.gz"
DOWNLOAD_PAGE="https://cangjie-lang.cn/download/${CANGJIE_VERSION}"
CALLBACK_BASE="${CANGJIE_SDK_CALLBACK_BASE:-https://huqi-blog.obs.cn-north-4.myhuaweicloud.com:443/cangjie}"
CACHE_DIR="${CANGJIE_CACHE_DIR:-${RUNNER_TEMP:-/tmp}/cangjie-sdk-cache}"
SDK_ARCHIVE="${CACHE_DIR}/${SDK_FILE}"
SDK_ROOT="${CACHE_DIR}/cangjie-${CANGJIE_VERSION}-${CANGJIE_PLATFORM}"

# Official checksum displayed by the Cangjie 1.1.3 download page. An explicit
# CANGJIE_SDK_SHA256 value always takes precedence.
if [[ -z "${CANGJIE_SDK_SHA256:-}" && "${CANGJIE_VERSION}" == "1.1.3" && "${CANGJIE_PLATFORM}" == "linux-x64" ]]; then
    CANGJIE_SDK_SHA256="2b68905afc466e665ae181595c63f96c18d75fd2c1fb6c6f0cb64e179c28d61a"
fi

mkdir -p "${CACHE_DIR}"

resolve_sdk_url() {
    # Highest priority: repository/environment override.
    if [[ -n "${CANGJIE_SDK_URL:-}" ]]; then
        printf '%s\n' "${CANGJIE_SDK_URL}"
        return 0
    fi

    # Stable callback mirror supplied by the repository owner. The filename is
    # version-derived, so this supports both 1.0.5 and 1.1.3 without branching.
    if [[ -n "${CALLBACK_BASE}" ]]; then
        printf '%s/%s\n' "${CALLBACK_BASE%/}" "${SDK_FILE}"
        return 0
    fi

    # Last-resort official-page discovery. Kept for users who intentionally set
    # CANGJIE_SDK_CALLBACK_BASE to an empty value.
    local dom_file
    dom_file="$(mktemp)"
    trap 'rm -f "${dom_file}"' RETURN

    local chrome_bin=""
    for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            chrome_bin="$(command -v "${candidate}")"
            break
        fi
    done

    if [[ -n "${chrome_bin}" ]]; then
        "${chrome_bin}" \
            --headless \
            --no-sandbox \
            --disable-gpu \
            --disable-dev-shm-usage \
            --virtual-time-budget=10000 \
            --dump-dom \
            "${DOWNLOAD_PAGE}" >"${dom_file}" 2>/dev/null || true
    fi

    if [[ ! -s "${dom_file}" ]]; then
        curl --fail --location --retry 3 --silent --show-error \
            "${DOWNLOAD_PAGE}" >"${dom_file}"
    fi

    local static_url=""
    static_url="$(python3 - "${dom_file}" "${SDK_FILE}" <<'PY'
import html
import re
import sys
from urllib.parse import urljoin

path, filename = sys.argv[1:]
text = html.unescape(open(path, encoding="utf-8", errors="ignore").read())
patterns = [
    rf'https?://[^\s"\'<>]+{re.escape(filename)}(?:\?[^\s"\'<>]*)?',
    rf'(?:href|data-url|download-url)=["\']([^"\']*{re.escape(filename)}[^"\']*)["\']',
]
for pattern in patterns:
    match = re.search(pattern, text)
    if not match:
        continue
    value = match.group(1) if match.lastindex else match.group(0)
    print(urljoin("https://cangjie-lang.cn/", value))
    break
PY
)"
    if [[ -n "${static_url}" ]]; then
        printf '%s\n' "${static_url}"
        return 0
    fi

    if [[ -z "${chrome_bin}" ]]; then
        echo "Chrome is required to resolve the dynamic Cangjie SDK Link control" >&2
        return 1
    fi

    echo "Resolving dynamic Cangjie SDK link through the official download UI" >&2
    python3 -m pip install --disable-pip-version-check --quiet selenium
    python3 "${SCRIPT_DIR}/resolve-cangjie-sdk-url.py" \
        "${DOWNLOAD_PAGE}" "${SDK_FILE}"
}

if [[ ! -f "${SDK_ARCHIVE}" ]]; then
    SDK_URL="$(resolve_sdk_url)"
    echo "Downloading ${SDK_FILE} from ${SDK_URL}"
    curl --fail --location --retry 3 --retry-delay 5 --silent --show-error \
        --output "${SDK_ARCHIVE}.part" "${SDK_URL}"
    mv "${SDK_ARCHIVE}.part" "${SDK_ARCHIVE}"
fi

if [[ -n "${CANGJIE_SDK_SHA256:-}" ]]; then
    if ! printf '%s  %s\n' "${CANGJIE_SDK_SHA256}" "${SDK_ARCHIVE}" | sha256sum --check --status; then
        rm -f "${SDK_ARCHIVE}"
        echo "SHA256 verification failed for ${SDK_FILE}" >&2
        exit 1
    fi
    echo "Verified SHA256 for ${SDK_FILE}"
fi

if [[ ! -f "${SDK_ROOT}/.installed" ]]; then
    rm -rf "${SDK_ROOT}"
    mkdir -p "${SDK_ROOT}"
    tar -xzf "${SDK_ARCHIVE}" -C "${SDK_ROOT}"
    touch "${SDK_ROOT}/.installed"
fi

ENVSETUP="$(find "${SDK_ROOT}" -type f -name envsetup.sh -print -quit)"
if [[ -z "${ENVSETUP}" ]]; then
    echo "envsetup.sh was not found after extracting ${SDK_FILE}" >&2
    exit 1
fi

# The official envsetup.sh reads variables such as LD_LIBRARY_PATH before they
# are defined. Temporarily disable nounset while loading it, then restore the
# script's strict mode for all subsequent commands.
# shellcheck disable=SC1090
set +u
source "${ENVSETUP}"
set -u

cjc -v
cjpm -h >/dev/null

echo "CANGJIE_ENVSETUP=${ENVSETUP}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "envsetup=${ENVSETUP}" >>"${GITHUB_OUTPUT}"
fi
