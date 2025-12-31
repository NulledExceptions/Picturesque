# Picturesque macOS Installer

## Installation

1. **Open the DMG**: Double-click `Picturesque-OSX.dmg`
2. **Install the App**: Drag `Picturesque-OSX.app` to the `Applications` folder
3. **Launch**: Open Picturesque from your Applications folder

## First Launch Setup

On first launch, Picturesque will automatically:
- Create a Python virtual environment
- Install required dependencies (PyTorch, Diffusers, etc.)
- This may take 2-5 minutes depending on your internet connection

## Using Picturesque

### Quick Start
1. Click "Select Image" or drag & drop a photo
2. Choose your style (Anime, Cartoon, etc.)
3. Adjust settings if desired:
   - **Strength**: 0.75-0.85 for best cartoon results
   - **Guidance Scale**: 7.5 for creative output
   - **Steps**: 30 for good quality/speed balance
4. Click "Generate"

### Optimal Settings for Photo-to-Cartoon
- **Strength**: 0.80 (default) - transforms photo while keeping composition
- **Guidance Scale**: 7.5 - allows creative cartoon styling
- **Steps**: 30 - good balance of quality and speed
- **Max Resolution**: 768 - recommended for most images

## Performance

### CPU Mode (Default)
- Works on all Macs
- Generation time: 2-5 minutes per image
- Uses `torch.float32` for compatibility

### GPU Mode (Apple Silicon)
To enable faster generation with Apple Silicon GPU:
1. The app will automatically use MPS (Metal Performance Shaders) when available
2. For even faster generation (5-15 seconds):
   - Download CoreML models (instructions in app)
   - Models will be auto-detected and used

## App Support Files

Picturesque stores files at:
- **Python Environment**: `~/Library/Application Support/Picturesque/venv/`
- **Scripts**: `~/Library/Application Support/Picturesque/scripts/`
- **Outputs**: `~/Library/Application Support/Picturesque/outputs/`
- **Temp Files**: `~/Library/Application Support/Picturesque/temp/`

## Troubleshooting

### Generation Fails
- Check that Python dependencies installed correctly
- Ensure you have internet connection for first run
- Try restarting the app

### Slow Performance
- CPU mode is slower but works everywhere
- For faster generation, ensure Apple Silicon Mac and download CoreML models

### Quality Issues
- Increase **Strength** (0.75-0.85) for stronger cartoon effect
- Adjust **Guidance Scale** for different styles
- Try different prompts in "Prompt Extra" field

## System Requirements

- **macOS**: 13.5 or later
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 5-10GB for models and cache
- **Processor**: Intel or Apple Silicon (M1/M2/M3/M4)

## Privacy

Picturesque runs entirely locally on your Mac:
- No internet connection required after initial setup
- Images never leave your computer
- No data collection or tracking

## Version Information

Built with:
- Swift 5.0
- PyTorch (latest stable)
- Diffusers library
- Stable Diffusion models

---

**Enjoy creating beautiful AI artwork with Picturesque!** 🎨✨
