#!/usr/bin/env python3
"""
Professional Phi-3 Mini Model Setup Script
For NotedCore Medical Transcription App

This script downloads and prepares the Phi-3 Mini model for integration
into the iOS app bundle for offline medical note generation.
"""

import os
import sys
import shutil
import json
from pathlib import Path
import subprocess
import tempfile

# Configuration
MODEL_NAME = "mlx-community/Phi-3-mini-4k-instruct-4bit"
PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT_PATH = PROJECT_ROOT / "NotedCore"
MODELS_DIR = XCODE_PROJECT_PATH / "Models"

def check_requirements():
    """Check if required tools are installed."""
    print("🔍 Checking requirements...")
    
    # Check Python version
    if sys.version_info < (3, 8):
        print("❌ Python 3.8+ required")
        return False
    
    # Check if mlx-lm is installed
    try:
        import mlx_lm
        print("✅ mlx-lm is installed")
    except ImportError:
        print("❌ mlx-lm not found. Installing...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "mlx-lm"])
            print("✅ mlx-lm installed successfully")
        except subprocess.CalledProcessError:
            print("❌ Failed to install mlx-lm")
            return False
    
    return True

def create_models_directory():
    """Create models directory in Xcode project."""
    print("📁 Creating models directory...")
    MODELS_DIR.mkdir(exist_ok=True)
    print(f"✅ Models directory: {MODELS_DIR}")

def download_model():
    """Download Phi-3 Mini model using mlx-lm."""
    print(f"⬇️ Downloading {MODEL_NAME}...")
    print("   This may take several minutes depending on your internet connection...")
    
    try:
        from mlx_lm import load
        
        # Download model to temporary directory first
        with tempfile.TemporaryDirectory() as temp_dir:
            print(f"   Downloading to temporary directory: {temp_dir}")
            
            # Load model (this triggers download)
            model, tokenizer = load(MODEL_NAME)
            
            # The model files are now cached in ~/.cache/huggingface/hub/
            # We need to copy them to our project
            
            print("✅ Model downloaded successfully")
            return True
            
    except Exception as e:
        print(f"❌ Failed to download model: {e}")
        return False

def find_model_files():
    """Find the downloaded model files in the HuggingFace cache."""
    print("🔍 Locating model files...")
    
    # HuggingFace cache directory
    cache_dir = Path.home() / ".cache" / "huggingface" / "hub"
    
    # Look for Phi-3 model directory
    model_dirs = list(cache_dir.glob("models--mlx-community--Phi-3-mini-4k-instruct-4bit"))
    
    if not model_dirs:
        print("❌ Model cache directory not found")
        return None
    
    model_dir = model_dirs[0] / "snapshots"
    
    # Get the latest snapshot
    snapshot_dirs = list(model_dir.iterdir())
    if not snapshot_dirs:
        print("❌ No model snapshots found")
        return None
    
    latest_snapshot = max(snapshot_dirs, key=lambda p: p.stat().st_mtime)
    print(f"✅ Found model files in: {latest_snapshot}")
    
    return latest_snapshot

def copy_model_files(source_dir):
    """Copy model files to Xcode project."""
    print("📋 Copying model files to Xcode project...")
    
    # Required files
    required_files = {
        "config.json": "phi-3-config.json",
        "tokenizer.json": "phi-3-tokenizer.json", 
        "model.safetensors": "phi-3-mini.mlx",
        "tokenizer_config.json": "phi-3-tokenizer-config.json"
    }
    
    copied_files = []
    
    for source_file, dest_file in required_files.items():
        source_path = source_dir / source_file
        dest_path = MODELS_DIR / dest_file
        
        if source_path.exists():
            shutil.copy2(source_path, dest_path)
            print(f"✅ Copied: {source_file} -> {dest_file}")
            copied_files.append(dest_file)
        else:
            print(f"⚠️  File not found: {source_file}")
    
    return copied_files

def update_xcode_project(model_files):
    """Add model files to Xcode project."""
    print("🔧 Updating Xcode project...")
    
    # Instructions for manual addition
    print("\n" + "="*60)
    print("XCODE PROJECT SETUP REQUIRED")
    print("="*60)
    print("Please add the following files to your Xcode project:")
    print(f"Location: {MODELS_DIR}")
    print("\nFiles to add:")
    
    for file in model_files:
        print(f"  • {file}")
    
    print("\nInstructions:")
    print("1. Open NotedCore.xcodeproj in Xcode")
    print("2. Right-click on 'NotedCore' group")
    print("3. Select 'Add Files to NotedCore'")
    print("4. Navigate to the Models folder")
    print("5. Select all the model files")
    print("6. Ensure 'Add to target: NotedCore' is checked")
    print("7. Click 'Add'")
    print("\nIMPORTANT: Make sure files are added to the app bundle!")
    print("="*60)

def create_model_info():
    """Create model information file."""
    model_info = {
        "model_name": "Phi-3 Mini 4K Instruct",
        "model_version": "4bit",
        "context_length": 4096,
        "parameters": "3.8B",
        "quantization": "4bit",
        "source": MODEL_NAME,
        "license": "MIT",
        "intended_use": "Medical note generation",
        "setup_date": subprocess.check_output(["date", "+%Y-%m-%d"]).decode().strip()
    }
    
    info_file = MODELS_DIR / "model_info.json"
    with open(info_file, 'w') as f:
        json.dump(model_info, f, indent=2)
    
    print(f"✅ Created model info: {info_file}")

def main():
    """Main setup function."""
    print("🏥 NotedCore Medical Transcription - Phi-3 Mini Setup")
    print("="*60)
    
    # Check requirements
    if not check_requirements():
        print("❌ Setup failed - requirements not met")
        return 1
    
    # Create directories
    create_models_directory()
    
    # Download model
    if not download_model():
        print("❌ Setup failed - model download failed")
        return 1
    
    # Find model files
    model_dir = find_model_files()
    if not model_dir:
        print("❌ Setup failed - model files not found")
        return 1
    
    # Copy files
    copied_files = copy_model_files(model_dir)
    if not copied_files:
        print("❌ Setup failed - no files copied")
        return 1
    
    # Create model info
    create_model_info()
    
    # Update Xcode project
    update_xcode_project(copied_files)
    
    print("\n✅ Setup completed successfully!")
    print("   Follow the Xcode instructions above to complete the integration.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())