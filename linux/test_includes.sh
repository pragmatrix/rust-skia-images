#!/bin/bash
set -e

echo "========================================="
echo "Testing C++ include paths for targets"
echo "========================================="
echo ""

echo "=== x86_64-unknown-linux-gnu include directories ==="
clang++ -target x86_64-unknown-linux-gnu -v -E -x c++ - < /dev/null 2>&1 | grep -A 30 "include <...> search starts here:"
echo ""

echo "=== aarch64-unknown-linux-gnu include directories ==="
clang++ -target aarch64-unknown-linux-gnu -v -E -x c++ - < /dev/null 2>&1 | grep -A 30 "include <...> search starts here:"
echo ""

echo "========================================="
echo "Testing if <compare> header is available"
echo "========================================="
echo ""

echo "=== Testing x86_64-unknown-linux-gnu with <compare> ==="
if echo '#include <compare>' | clang++ -target x86_64-unknown-linux-gnu -std=c++20 -fsyntax-only -x c++ - 2>&1; then
    echo "✓ <compare> header found for x86_64-unknown-linux-gnu"
else
    echo "✗ <compare> header NOT found for x86_64-unknown-linux-gnu"
fi
echo ""

echo "=== Testing aarch64-unknown-linux-gnu with <compare> ==="
if echo '#include <compare>' | clang++ -target aarch64-unknown-linux-gnu -std=c++20 -fsyntax-only -x c++ - 2>&1; then
    echo "✓ <compare> header found for aarch64-unknown-linux-gnu"
else
    echo "✗ <compare> header NOT found for aarch64-unknown-linux-gnu"
fi

echo "========================================="
echo "Testing if std::atomic wait is available"
echo "========================================="
echo ""

# Skia's Graphite backend calls std::atomic<T>::wait and notify_one, which need libstdc++ 11 or newer.
for target in x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu; do
    echo "=== Testing $target with std::atomic wait ==="
    if printf '#include <atomic>\nvoid f(std::atomic<bool>& a) { a.wait(false); a.notify_one(); }\n' \
        | clang++ -target "$target" -std=c++20 -fsyntax-only -x c++ - 2>&1; then
        echo "✓ std::atomic wait available for $target"
    else
        echo "✗ std::atomic wait NOT available for $target"
        exit 1
    fi
    echo ""
done
