#!/bin/bash
# ============================================
# Flutter Runner Wrapper - Linux/Mac
# Menyaring peringatan KGP dari output terminal
# ============================================
# Usage: ./run.sh <flutter-command> [arguments]
# Example: ./run.sh run
# Example: ./run.sh build apk
# ============================================

if [ -z "$1" ]; then
    echo "Usage: ./run.sh <flutter-command> [arguments]"
    echo ""
    echo "Examples:"
    echo "  ./run.sh run"
    echo "  ./run.sh build apk --debug"
    echo "  ./run.sh clean"
    exit 1
fi

set -o pipefail
flutter "$@" 2>&1 | grep -v "Kotlin Gradle Plugin (KGP)\|Future versions of Flutter"
exit ${PIPESTATUS[0]}