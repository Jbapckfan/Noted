#!/bin/bash

# Medical Dataset Download Script
# Run this script to download MTS-Dialog and PriMock57 datasets

echo "🏥 Medical Dataset Downloader"
echo "================================"

# Create datasets directory
DATASETS_DIR="$(pwd)/MedicalDatasets"
mkdir -p "$DATASETS_DIR"
cd "$DATASETS_DIR"

echo "📁 Created datasets directory: $DATASETS_DIR"

# Check if Git LFS is installed
if ! command -v git-lfs &> /dev/null; then
    echo "⚠️  Git LFS not found. Installing Git LFS..."
    # On macOS with Homebrew
    if command -v brew &> /dev/null; then
        brew install git-lfs
    else
        echo "❌ Please install Git LFS manually: https://git-lfs.github.io/"
        exit 1
    fi
fi

# Initialize Git LFS
git lfs install
echo "✅ Git LFS initialized"

# Download MTS-Dialog dataset (1,700 conversations)
echo ""
echo "📥 Downloading MTS-Dialog dataset..."
if [ -d "MTS-Dialog" ]; then
    echo "⏩ MTS-Dialog already exists, skipping..."
else
    git clone https://github.com/abachaa/MTS-Dialog.git
    if [ $? -eq 0 ]; then
        echo "✅ MTS-Dialog downloaded successfully"
        echo "📊 Contains: 1,700+ medical conversations with clinical notes"
    else
        echo "❌ Failed to download MTS-Dialog"
    fi
fi

# Download PriMock57 dataset (57 consultations with audio)
echo ""
echo "📥 Downloading PriMock57 dataset..."
if [ -d "primock57" ]; then
    echo "⏩ PriMock57 already exists, skipping..."
else
    git clone https://github.com/babylonhealth/primock57.git
    if [ $? -eq 0 ]; then
        echo "✅ PriMock57 downloaded successfully"
        echo "📊 Contains: 57 primary care consultations with audio + transcripts"
        
        # Check audio files
        audio_count=$(find primock57/audio -name "*.wav" 2>/dev/null | wc -l)
        echo "🎵 Audio files downloaded: $audio_count"
    else
        echo "❌ Failed to download PriMock57"
    fi
fi

# Summary
echo ""
echo "📋 Download Summary:"
echo "===================="
echo "📍 Datasets location: $DATASETS_DIR"

if [ -d "MTS-Dialog" ]; then
    mts_files=$(find MTS-Dialog -name "*.json" 2>/dev/null | wc -l)
    echo "✅ MTS-Dialog: $mts_files JSON files"
fi

if [ -d "primock57" ]; then
    audio_files=$(find primock57/audio -name "*.wav" 2>/dev/null | wc -l)
    transcript_files=$(find primock57/transcripts -name "*.txt" 2>/dev/null | wc -l)
    notes_files=$(find primock57/notes -name "*.txt" 2>/dev/null | wc -l)
    echo "✅ PriMock57: $audio_files audio, $transcript_files transcripts, $notes_files notes"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Update NotedCore to point to: $DATASETS_DIR"
echo "2. Run training via the MedicalTrainingView UI"
echo "3. Monitor training progress and metrics"
echo ""
echo "✨ Ready to train your medical AI model!"