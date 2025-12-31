#!/usr/bin/env python3
"""
Download Core ML Stable Diffusion models from Hugging Face
"""
import os
import sys
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("Installing huggingface_hub...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "huggingface-hub"])
    from huggingface_hub import snapshot_download

def download_coreml_model(model_id: str, output_dir: Path, variant: str = "original"):
    """
    Download a Core ML Stable Diffusion model from Hugging Face

    Args:
        model_id: HuggingFace model ID (e.g., "apple/coreml-stable-diffusion-v1-5")
        output_dir: Local directory to save the model
        variant: Model variant - "original" or "split_einsum"
    """
    print(f"Downloading {model_id} ({variant} variant)...")
    print(f"Destination: {output_dir}")

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Download the model
    # We want the "compiled" version for Swift inference
    allow_patterns = [
        f"*{variant}/compiled/*",
        "*.json",
        "*.txt",
        "LICENSE"
    ]

    try:
        local_path = snapshot_download(
            repo_id=model_id,
            allow_patterns=allow_patterns,
            local_dir=output_dir,
            local_dir_use_symlinks=False
        )
        print(f"✓ Download complete: {local_path}")
        return True
    except Exception as e:
        print(f"✗ Download failed: {e}")
        return False

def main():
    # Get the app support directory
    home = Path.home()
    app_support = home / "Library" / "Application Support" / "Picturesque" / "CoreMLModels"

    print("=" * 60)
    print("Core ML Stable Diffusion Model Downloader")
    print("=" * 60)
    print()

    # Available models
    models = {
        "1": {
            "name": "Stable Diffusion 1.5",
            "id": "apple/coreml-stable-diffusion-v1-5",
            "size": "~2.5 GB"
        },
        "2": {
            "name": "Stable Diffusion 2.1 Base",
            "id": "apple/coreml-stable-diffusion-2-1-base",
            "size": "~2.5 GB"
        }
    }

    print("Available models:")
    for key, info in models.items():
        print(f"  {key}. {info['name']} ({info['size']})")
    print()

    choice = input("Select model to download (1-2, or 'q' to quit): ").strip()

    if choice.lower() == 'q':
        print("Cancelled.")
        return

    if choice not in models:
        print("Invalid choice.")
        return

    model_info = models[choice]
    model_dir = app_support / model_info["id"].replace("/", "_")

    print()
    print(f"Downloading: {model_info['name']}")
    print(f"This will download approximately {model_info['size']}")
    print()

    # Download the model
    success = download_coreml_model(
        model_id=model_info["id"],
        output_dir=model_dir,
        variant="original"  # Use original variant (more compatible)
    )

    if success:
        print()
        print("=" * 60)
        print("✓ Download complete!")
        print(f"Model saved to: {model_dir}")
        print("=" * 60)
    else:
        print()
        print("=" * 60)
        print("✗ Download failed. Please try again.")
        print("=" * 60)
        sys.exit(1)

if __name__ == "__main__":
    main()
