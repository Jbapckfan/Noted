#!/usr/bin/env python3
"""
Professional Phi-3 Mini Model Setup Script with Virtual Environment
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
import venv

# Configuration
MODEL_NAME = "mlx-community/Phi-3-mini-4k-instruct-4bit"
PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT_PATH = PROJECT_ROOT / "NotedCore"
MODELS_DIR = XCODE_PROJECT_PATH / "Models"
VENV_DIR = PROJECT_ROOT / "venv"

def setup_virtual_environment():
    """Create and activate virtual environment."""
    print("🔧 Setting up virtual environment...")
    
    if not VENV_DIR.exists():
        print(f"   Creating virtual environment at: {VENV_DIR}")
        venv.create(VENV_DIR, with_pip=True)
    
    # Get paths for the virtual environment
    if sys.platform == "darwin":  # macOS
        pip_path = VENV_DIR / "bin" / "pip"
        python_path = VENV_DIR / "bin" / "python"
    else:
        pip_path = VENV_DIR / "Scripts" / "pip"
        python_path = VENV_DIR / "Scripts" / "python"
    
    return str(python_path), str(pip_path)

def install_requirements(pip_path):
    """Install required packages in virtual environment."""
    print("📦 Installing required packages...")
    
    try:
        # Upgrade pip first
        subprocess.check_call([pip_path, "install", "--upgrade", "pip"])
        
        # Install mlx-lm
        print("   Installing mlx-lm...")
        subprocess.check_call([pip_path, "install", "mlx-lm"])
        
        print("✅ All packages installed successfully")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install packages: {e}")
        return False

def check_requirements(python_path):
    """Check if required tools are installed."""
    print("🔍 Checking requirements...")
    
    # Check Python version
    if sys.version_info < (3, 8):
        print("❌ Python 3.8+ required")
        return False
    
    # Check if mlx-lm is installed in venv
    try:
        subprocess.check_output([python_path, "-c", "import mlx_lm"])
        print("✅ mlx-lm is installed")
        return True
    except subprocess.CalledProcessError:
        print("❌ mlx-lm not found in virtual environment")
        return False

def create_models_directory():
    """Create models directory in Xcode project."""
    print("📁 Creating models directory...")
    MODELS_DIR.mkdir(exist_ok=True)
    print(f"✅ Models directory: {MODELS_DIR}")

def download_model(python_path):
    """Download Phi-3 Mini model using mlx-lm."""
    print(f"⬇️ Downloading {MODEL_NAME}...")
    print("   This may take several minutes depending on your internet connection...")
    
    # Create a Python script to download the model
    download_script = f'''
import sys
from mlx_lm import load
import json

print("Loading model...")
try:
    model, tokenizer = load("{MODEL_NAME}")
    print("Model loaded successfully!")
    
    # Save model info
    info = {{
        "status": "success",
        "model": "{MODEL_NAME}",
        "type": type(model).__name__,
        "tokenizer": type(tokenizer).__name__
    }}
    
    with open("model_load_info.json", "w") as f:
        json.dump(info, f)
        
except Exception as e:
    print(f"Error: {{e}}")
    info = {{"status": "error", "message": str(e)}}
    with open("model_load_info.json", "w") as f:
        json.dump(info, f)
    sys.exit(1)
'''
    
    # Write and execute the download script
    script_path = PROJECT_ROOT / "download_model.py"
    with open(script_path, "w") as f:
        f.write(download_script)
    
    try:
        subprocess.check_call([python_path, str(script_path)])
        
        # Check if download was successful
        info_path = PROJECT_ROOT / "model_load_info.json"
        if info_path.exists():
            with open(info_path, "r") as f:
                info = json.load(f)
            
            # Clean up
            os.remove(script_path)
            os.remove(info_path)
            
            if info["status"] == "success":
                print("✅ Model downloaded successfully")
                return True
            else:
                print(f"❌ Model download failed: {info.get('message', 'Unknown error')}")
                return False
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to download model: {e}")
        if script_path.exists():
            os.remove(script_path)
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
    
    # Files to copy with their mappings
    file_mappings = {
        "config.json": "phi-3-config.json",
        "tokenizer.json": "phi-3-tokenizer.json",
        "tokenizer_config.json": "phi-3-tokenizer-config.json"
    }
    
    # Find the weights file (could be .safetensors or .npz)
    weights_files = list(source_dir.glob("*.safetensors")) + list(source_dir.glob("*.npz"))
    if weights_files:
        # Use the first weights file found
        weights_file = weights_files[0]
        file_mappings[weights_file.name] = "phi-3-mini.mlx"
    
    copied_files = []
    
    for source_file, dest_file in file_mappings.items():
        source_path = source_dir / source_file if isinstance(source_file, str) else Path(source_file)
        dest_path = MODELS_DIR / dest_file
        
        if source_path.exists():
            shutil.copy2(source_path, dest_path)
            print(f"✅ Copied: {source_path.name} -> {dest_file}")
            copied_files.append(dest_file)
        else:
            print(f"⚠️  File not found: {source_path}")
    
    # Copy any additional MLX files
    for mlx_file in source_dir.glob("*.mlx*"):
        if mlx_file.name not in [f.name for f in copied_files]:
            dest_path = MODELS_DIR / mlx_file.name
            shutil.copy2(mlx_file, dest_path)
            print(f"✅ Copied: {mlx_file.name}")
            copied_files.append(mlx_file.name)
    
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
    
    # Setup virtual environment
    python_path, pip_path = setup_virtual_environment()
    
    # Install requirements
    if not install_requirements(pip_path):
        print("❌ Setup failed - could not install requirements")
        return 1
    
    # Check requirements
    if not check_requirements(python_path):
        print("❌ Setup failed - requirements not met")
        return 1
    
    # Create directories
    create_models_directory()
    
    # Download model
    if not download_model(python_path):
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
    print("\n💡 Tip: The virtual environment is at:", VENV_DIR)
    print("   You can activate it with: source venv/bin/activate")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())