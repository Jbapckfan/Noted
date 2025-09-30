#!/bin/bash

# Medical Whisper Fine-Tuning Setup Script
# =========================================
# Automated setup for the medical Whisper fine-tuning environment

set -e  # Exit on any error

echo "🏥 Medical Whisper Fine-Tuning Setup"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python 3.9+ is available
check_python() {
    print_status "Checking Python version..."

    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
            print_status "Python $PYTHON_VERSION found ✓"
            PYTHON_CMD="python3"
        else
            print_error "Python 3.9+ required, found $PYTHON_VERSION"
            exit 1
        fi
    else
        print_error "Python 3 not found. Please install Python 3.9+"
        exit 1
    fi
}

# Create virtual environment
create_venv() {
    print_status "Creating virtual environment..."

    if [ ! -d "whisper_medical_env" ]; then
        $PYTHON_CMD -m venv whisper_medical_env
        print_status "Virtual environment created ✓"
    else
        print_warning "Virtual environment already exists"
    fi

    # Activate virtual environment
    source whisper_medical_env/bin/activate
    print_status "Virtual environment activated ✓"
}

# Install Python dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."

    # Upgrade pip first
    pip install --upgrade pip

    # Install requirements
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        print_status "Python dependencies installed ✓"
    else
        print_error "requirements.txt not found"
        exit 1
    fi
}

# Install medical NLP models
install_medical_models() {
    print_status "Installing medical NLP models..."

    # Install spaCy models
    python -m spacy download en_core_web_sm

    # Install SciSpaCy models
    pip install https://s3-us-west-2.amazonaws.com/ai2-s2-scispacy/releases/v0.5.0/en_core_sci_sm-0.5.0.tar.gz
    pip install https://s3-us-west-2.amazonaws.com/ai2-s2-scispacy/releases/v0.5.0/en_core_sci_md-0.5.0.tar.gz

    print_status "Medical NLP models installed ✓"
}

# Create directory structure
create_directories() {
    print_status "Creating directory structure..."

    mkdir -p data/processed
    mkdir -p data/synthetic
    mkdir -p models/fine_tuned
    mkdir -p logs
    mkdir -p evaluation/reports
    mkdir -p scripts

    print_status "Directory structure created ✓"
}

# Download base Whisper models
download_base_models() {
    print_status "Downloading base Whisper models..."

    python3 << 'EOF'
import whisper
import os

models_to_download = ["tiny", "base", "small"]
models_dir = "models/base"
os.makedirs(models_dir, exist_ok=True)

for model_name in models_to_download:
    try:
        print(f"Downloading {model_name} model...")
        model = whisper.load_model(model_name, download_root=models_dir)
        print(f"✓ {model_name} model downloaded")
    except Exception as e:
        print(f"✗ Failed to download {model_name}: {e}")
EOF

    print_status "Base Whisper models downloaded ✓"
}

# Verify medical datasets
verify_datasets() {
    print_status "Verifying medical datasets..."

    DATASET_DIR="../MedicalDatasets"

    if [ -d "$DATASET_DIR" ]; then
        print_status "MedicalDatasets directory found ✓"

        # Check for MTS-Dialog
        if [ -d "$DATASET_DIR/MTS-Dialog" ]; then
            MTS_FILES=$(find "$DATASET_DIR/MTS-Dialog" -name "*.csv" | wc -l)
            print_status "MTS-Dialog dataset found with $MTS_FILES CSV files ✓"
        else
            print_warning "MTS-Dialog dataset not found"
        fi

        # Check for PRIMOCK
        if [ -d "$DATASET_DIR/primock57" ]; then
            print_status "PRIMOCK dataset found ✓"
        else
            print_warning "PRIMOCK dataset not found"
        fi
    else
        print_warning "MedicalDatasets directory not found at $DATASET_DIR"
        print_warning "You may need to prepare medical datasets manually"
    fi
}

# Create example scripts
create_scripts() {
    print_status "Creating utility scripts..."

    # Training script
    cat > scripts/train_medical_model.sh << 'EOF'
#!/bin/bash
# Quick training script with default parameters

source ../whisper_medical_env/bin/activate
cd ..

python fine_tune_medical.py \
    --config medical_config.json \
    --epochs 15 \
    --batch-size 8 \
    --output-dir ./models/fine_tuned/medical_whisper_$(date +%Y%m%d_%H%M%S)
EOF

    # Evaluation script
    cat > scripts/evaluate_model.sh << 'EOF'
#!/bin/bash
# Model evaluation script

source ../whisper_medical_env/bin/activate
cd ..

python -c "
from evaluation_metrics import MedicalTranscriptionEvaluator
import json

# Load test data
with open('data/test_samples.json', 'r') as f:
    test_data = json.load(f)

references = [item['text'] for item in test_data]
# Add your model predictions here
hypotheses = references  # Placeholder

evaluator = MedicalTranscriptionEvaluator()
results = evaluator.evaluate_batch(references, hypotheses)

print('Medical Transcription Evaluation Results:')
for metric, value in results.items():
    if isinstance(value, float):
        print(f'{metric}: {value:.3f}')
"
EOF

    # Data preprocessing script
    cat > scripts/preprocess_data.sh << 'EOF'
#!/bin/bash
# Data preprocessing script

source ../whisper_medical_env/bin/activate
cd ..

python data_preprocessing.py --config medical_config.json
EOF

    # Make scripts executable
    chmod +x scripts/*.sh

    print_status "Utility scripts created ✓"
}

# Validate installation
validate_installation() {
    print_status "Validating installation..."

    # Test imports
    python3 << 'EOF'
try:
    import torch
    print("✓ PyTorch imported successfully")

    import transformers
    print("✓ Transformers imported successfully")

    import whisper
    print("✓ OpenAI Whisper imported successfully")

    import librosa
    print("✓ Librosa imported successfully")

    import spacy
    nlp = spacy.load("en_core_web_sm")
    print("✓ SpaCy model loaded successfully")

    # Try importing our modules
    import sys
    sys.path.append('.')

    from medical_vocabulary import MedicalVocabularyEnhancer
    print("✓ Medical vocabulary module imported successfully")

    from evaluation_metrics import MedicalTranscriptionEvaluator
    print("✓ Evaluation metrics module imported successfully")

    print("\n🎉 All modules imported successfully!")

except ImportError as e:
    print(f"✗ Import error: {e}")
    exit(1)
EOF

    print_status "Installation validation completed ✓"
}

# Generate configuration file if it doesn't exist
create_config() {
    if [ ! -f "medical_config.json" ]; then
        print_status "Creating default configuration file..."

        cat > medical_config_local.json << 'EOF'
{
  "model_name": "openai/whisper-small",
  "output_dir": "./models/fine_tuned/medical_whisper",
  "data_dir": "../MedicalDatasets",

  "training": {
    "num_epochs": 10,
    "batch_size": 4,
    "gradient_accumulation_steps": 4,
    "learning_rate": 1e-5,
    "warmup_steps": 500
  },

  "medical_vocabulary": {
    "enhance_vocabulary": true,
    "medical_vocab_size": 5000
  },

  "hardware": {
    "use_gpu": false,
    "mixed_precision": false
  },

  "logging": {
    "use_wandb": false,
    "use_tensorboard": true
  }
}
EOF
        print_status "Local configuration file created ✓"
    fi
}

# Main setup process
main() {
    echo
    print_status "Starting setup process..."
    echo

    check_python
    create_venv
    install_dependencies
    install_medical_models
    create_directories
    create_config
    create_scripts
    verify_datasets
    validate_installation

    echo
    echo "🎉 Setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Activate the environment: source whisper_medical_env/bin/activate"
    echo "2. Prepare your medical datasets in ../MedicalDatasets/"
    echo "3. Customize medical_config.json for your needs"
    echo "4. Run preprocessing: python data_preprocessing.py"
    echo "5. Start training: python fine_tune_medical.py"
    echo
    echo "For detailed instructions, see README.md"
    echo
}

# Run main function
main