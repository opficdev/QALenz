#!/bin/bash

set -euo pipefail

if [ "${SWIFTLINT_PLUGIN_SKIP:-}" = "true" ]; then
	exit 0
fi

if ! command -v swiftlint >/dev/null 2>&1; then
	echo "SwiftLint가 설치되어 있지 않습니다."
	echo "Homebrew로 설치한 뒤 다시 실행해 주세요:"
	echo "brew install swiftlint"
	exit 1
fi

repositoryRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repositoryRoot"

arguments=(lint --no-cache --config .swiftlint.yml)

if [ "${SWIFTLINT_STRICT:-true}" != "false" ]; then
	arguments+=(--strict)
fi

swiftlint "${arguments[@]}"
