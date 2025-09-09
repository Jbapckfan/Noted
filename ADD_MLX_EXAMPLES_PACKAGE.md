# Add MLX Swift Examples Package

To enable real Phi-3 AI functionality, you need to add the MLX Swift Examples package to your Xcode project:

## Steps to Add Package

1. **Open NotedCore.xcodeproj in Xcode**

2. **Add Package Dependency:**
   - Click on the NotedCore project in the navigator
   - Select the NotedCore target
   - Go to the "Package Dependencies" tab
   - Click the "+" button
   - Enter this URL: `https://github.com/ml-explore/mlx-swift-examples`
   - Click "Add Package"
   - Wait for package resolution

3. **Select Products:**
   When prompted, add these products to your NotedCore target:
   - ✅ MLXLLM
   - ✅ MLXLMCommon
   
4. **Build the Project:**
   - Press Cmd+B to build
   - The first build may take a while as it downloads dependencies

## What This Enables

- Real Phi-3 model loading and inference
- Automatic model downloading from Hugging Face
- Proper tokenization and text generation
- Medical note generation using actual AI

## Troubleshooting

If you encounter issues:
1. Clean build folder (Shift+Cmd+K)
2. Reset package caches: File → Packages → Reset Package Caches
3. Ensure you have an internet connection for first model download

## Note
The Phi-3 model (2GB) will be downloaded on first use when connected to the internet.