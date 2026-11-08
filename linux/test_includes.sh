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

echo "========================================="
echo "Testing the libstdc++ version clang selects"
echo "========================================="
echo ""

# clang picks the newest gcc installation it finds, which can differ from the one the Dockerfile
# intends. Binaries built here depend on the selected libstdc++, so a silent switch changes the
# baseline that rust-skia's prebuilt binaries require.
EXPECTED_GLIBCXX_RELEASE=11
for target in x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu; do
    release=$(echo '#include <cstddef>' \
        | clang++ -target "$target" -std=c++20 -dM -E -x c++ - \
        | awk '$2 == "_GLIBCXX_RELEASE" { print $3 }')
    if [ "$release" = "$EXPECTED_GLIBCXX_RELEASE" ]; then
        echo "✓ $target uses libstdc++ $release"
    else
        echo "✗ $target uses libstdc++ '$release', expected $EXPECTED_GLIBCXX_RELEASE"
        exit 1
    fi
done
