#!/bin/bash

echo "Building Three-Layer Architecture System..."

swiftc \
  NotedCore/ThreeLayerArchitecture.swift \
  test_three_layer_architecture.swift \
  -o test_three_layer

if [ $? -eq 0 ]; then
    echo "✓ Build successful"
    echo ""
    echo "Running demonstration..."
    echo ""
    ./test_three_layer
else
    echo "✗ Build failed"
    exit 1
fi
