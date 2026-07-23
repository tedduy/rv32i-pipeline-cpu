#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="${TOOLS_DIR:-${project_root}/.tools}"
downloads_dir="${tools_dir}/downloads"

oss_cad_archive="oss-cad-suite-linux-x64-20260508.tgz"
oss_cad_url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-05-08/${oss_cad_archive}"
oss_cad_sha256="c71735b02df363e2ad8e9f129e477e4f31b18d6532e9bed92eb8ad296101cb6f"

riscv_version="15.2-r1"
riscv_archive="riscstar-toolchain-${riscv_version}-x86_64-riscv32-none-elf.tar.xz"
riscv_url="https://releases.riscstar.com/toolchain/${riscv_version}/${riscv_archive}"
riscv_sha256="01a8229576102a75cf2031ad5993838ba27ebcca6ad8f2b02778d45eb8f0d266"

usage() {
    echo "Usage: $0 {all|oss-cad|riscv-toolchain}" >&2
}

require_host() {
    if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
        echo "This pinned binary bootstrap currently supports Linux x86_64 only." >&2
        echo "Override tool paths in Make when using another host platform." >&2
        exit 1
    fi

    local command_name
    for command_name in curl tar sha256sum mktemp awk; do
        command -v "${command_name}" >/dev/null 2>&1 || {
            echo "Missing host command: ${command_name}" >&2
            exit 1
        }
    done
}

download_verified() {
    local url="$1"
    local archive_path="$2"
    local expected_sha256="$3"
    local actual_sha256

    if [[ -f "${archive_path}" ]]; then
        actual_sha256="$(sha256sum "${archive_path}" | awk '{print $1}')"
        if [[ "${actual_sha256}" == "${expected_sha256}" ]]; then
            echo "Using cached $(basename "${archive_path}")"
            return
        fi
        echo "Cached archive checksum mismatch: ${archive_path}" >&2
        exit 1
    fi

    echo "Downloading $(basename "${archive_path}")"
    curl -L --fail --retry 3 --output "${archive_path}.part" "${url}"
    actual_sha256="$(sha256sum "${archive_path}.part" | awk '{print $1}')"
    if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
        echo "Checksum mismatch for $(basename "${archive_path}")" >&2
        rm -f "${archive_path}.part"
        exit 1
    fi
    mv "${archive_path}.part" "${archive_path}"
}

install_archive() {
    local name="$1"
    local url="$2"
    local archive_name="$3"
    local expected_sha256="$4"
    local destination="$5"
    local ready_file="$6"
    local archive_path="${downloads_dir}/${archive_name}"
    local staging_dir

    if [[ -x "${destination}/${ready_file}" ]]; then
        echo "${name}: already installed"
        return
    fi
    if [[ -e "${destination}" ]]; then
        echo "${name}: incomplete installation exists at ${destination}" >&2
        echo "Move it aside and rerun setup." >&2
        exit 1
    fi

    download_verified "${url}" "${archive_path}" "${expected_sha256}"
    staging_dir="$(mktemp -d "${tools_dir}/.${name}.XXXXXX")"
    tar -xf "${archive_path}" -C "${staging_dir}" --strip-components=1
    if [[ ! -x "${staging_dir}/${ready_file}" ]]; then
        rm -rf "${staging_dir}"
        echo "${name}: archive does not contain ${ready_file}" >&2
        exit 1
    fi
    mv "${staging_dir}" "${destination}"
    echo "${name}: installed at ${destination}"
}

main() {
    local component="${1:-all}"
    require_host
    mkdir -p "${tools_dir}" "${downloads_dir}"

    case "${component}" in
        all)
            install_archive \
                "oss-cad-suite" "${oss_cad_url}" "${oss_cad_archive}" \
                "${oss_cad_sha256}" "${tools_dir}/oss-cad-suite" "bin/verilator"
            install_archive \
                "riscv-toolchain" "${riscv_url}" "${riscv_archive}" \
                "${riscv_sha256}" "${tools_dir}/riscv-toolchain" \
                "bin/riscv32-none-elf-gcc"
            ;;
        oss-cad)
            install_archive \
                "oss-cad-suite" "${oss_cad_url}" "${oss_cad_archive}" \
                "${oss_cad_sha256}" "${tools_dir}/oss-cad-suite" "bin/verilator"
            ;;
        riscv-toolchain)
            install_archive \
                "riscv-toolchain" "${riscv_url}" "${riscv_archive}" \
                "${riscv_sha256}" "${tools_dir}/riscv-toolchain" \
                "bin/riscv32-none-elf-gcc"
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
