//
//  PythonBridge.swift
//  Picturesque-OSX
//
//  SIMPLE VERSION - Works with basic GenerationParameters (no modelId)
//

import Foundation
import AppKit

enum PythonBridgeError: Error {
    case pythonNotFound
    case venvCreationFailed
    case dependencyInstallFailed
    case generationFailed(String)
    case invalidOutput
}

class PythonBridge {
    private let appSupportURL: URL
    private let venvURL: URL
    private let pythonExecutable: URL
    private let scriptsURL: URL
    private var isInitialized = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("Picturesque", isDirectory: true)
        venvURL = appSupportURL.appendingPathComponent("venv", isDirectory: true)
        pythonExecutable = venvURL.appendingPathComponent("bin/python3")
        scriptsURL = appSupportURL.appendingPathComponent("scripts", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
    }
    
    func initialize(completion: @escaping (Bool, String) -> Void) {
        if isInitialized {
            completion(true, "Already initialized")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if !FileManager.default.fileExists(atPath: self.venvURL.path) {
                    try self.createVirtualEnvironment()
                }
                
                try self.installDependencies()
                try self.copyPythonScripts()
                
                self.isInitialized = true
                completion(true, "Initialized successfully")
                
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }
    
    private func createVirtualEnvironment() throws {
        print("[PythonBridge] Creating virtual environment...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "venv", venvURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw PythonBridgeError.venvCreationFailed
        }
    }
    
    private func installDependencies() throws {
        print("[PythonBridge] Installing dependencies...")

        let requirements = """
        numpy<2
        torch==2.2.0
        torchvision==0.17.0
        diffusers==0.26.3
        huggingface-hub==0.20.3
        transformers==4.37.2
        accelerate==0.26.1
        safetensors==0.4.2
        pillow==10.2.0
        """
        
        let requirementsPath = scriptsURL.appendingPathComponent("requirements.txt")
        try requirements.write(to: requirementsPath, atomically: true, encoding: .utf8)
        
        let process = Process()
        process.executableURL = pythonExecutable
        process.arguments = ["-m", "pip", "install", "-r", requirementsPath.path, "--quiet"]
        
        var env = ProcessInfo.processInfo.environment
        env["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"
        env["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        env["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"
        process.environment = env
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw PythonBridgeError.dependencyInstallFailed
        }
    }
    
    private func hasCoreMLModels() -> Bool {
        // Check if Core ML models have been downloaded
        let modelsURL = appSupportURL.appendingPathComponent("CoreMLModels", isDirectory: true)
        let sdv15 = modelsURL.appendingPathComponent("apple_coreml-stable-diffusion-v1-5/original/compiled")
        let sdv21 = modelsURL.appendingPathComponent("apple_coreml-stable-diffusion-2-1-base/original/compiled")

        let hasModels = FileManager.default.fileExists(atPath: sdv15.path) ||
                        FileManager.default.fileExists(atPath: sdv21.path)

        // Also check if the CoreML script exists
        let coreMLScript = scriptsURL.appendingPathComponent("cartoonizer_coreml.py")
        let hasScript = FileManager.default.fileExists(atPath: coreMLScript.path)

        return hasModels && hasScript
    }

    private func copyPythonScripts() throws {
        let scriptContent = """
#!/usr/bin/env python3
import argparse
import json
import sys
import traceback
import torch
from diffusers import StableDiffusionImg2ImgPipeline
from PIL import Image

def log(msg: str):
    print(f"[Picturesque] {msg}", flush=True)

def get_device(force_cpu=False) -> str:
    if force_cpu:
        return "cpu"
    if torch.backends.mps.is_available():
        return "mps"
    if torch.cuda.is_available():
        return "cuda"
    return "cpu"

def load_pipeline(model_id: str, device: str, force_cpu=False):
    import gc
    try:
        log(f"Loading model from {model_id}...")
        # Use float32 for CPU, float16 for GPU
        dtype = torch.float32 if (device == "cpu" or force_cpu) else torch.float16
        log(f"Using dtype: {dtype}")

        pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
            model_id, torch_dtype=dtype, safety_checker=None,
            low_cpu_mem_usage=True, use_safetensors=True)
    except Exception as e:
        log(f"Failed to load model with safetensors: {e}")
        try:
            # Fallback: try without safetensors
            dtype = torch.float32 if (device == "cpu" or force_cpu) else torch.float16
            pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
                model_id, torch_dtype=dtype, safety_checker=None,
                low_cpu_mem_usage=True)
        except Exception as e2:
            log(f"Fallback also failed: {e2}")
            raise

    # Try MPS first (M4 GPU), fallback to CPU if it fails
    if not force_cpu and device == "mps":
        try:
            log("Attempting to use MPS (Apple Silicon GPU)...")
            pipe = pipe.to("mps")
            # Enable memory optimizations for MPS
            pipe.enable_attention_slicing(1)

            # Enable VAE optimizations if available
            if hasattr(pipe, 'enable_vae_slicing'):
                pipe.enable_vae_slicing()
            if hasattr(pipe.vae, 'enable_slicing'):
                pipe.vae.enable_slicing()
            if hasattr(pipe.vae, 'enable_tiling'):
                pipe.vae.enable_tiling()

            log("✓ Using MPS (Apple Silicon GPU) for fast generation!")
        except Exception as e:
            log(f"MPS failed ({e}), falling back to CPU")
            device = "cpu"
            pipe = pipe.to("cpu")
            pipe.enable_attention_slicing(1)
    else:
        log("Using CPU mode")
        device = "cpu"
        pipe = pipe.to("cpu")
        pipe.enable_attention_slicing(1)

    # Force garbage collection
    gc.collect()
    log("Pipeline loaded and ready")
    return pipe, device

def prepare_image(path: str, max_side: int) -> Image.Image:
    img = Image.open(path).convert("RGB")
    w, h = img.size
    scale = min(max_side / max(w, h), 1.0)
    if scale < 1.0:
        img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    return img

def cartoonize(params):
    device = get_device(params.get("force_cpu", False))
    model_id = params.get("model_id", "Lykon/dreamshaper-8")
    
    log(f"Using model: {model_id}")
    pipe, actual_device = load_pipeline(model_id, device, params.get("force_cpu", False))
    
    presets = {
        "anime": "high quality anime portrait art, beautiful face, detailed eyes, vibrant colors, clean digital art",
        "comic": "comic book style portrait, bold ink lines, cel shading, colorful character art",
        "pixar": "pixar 3d rendered portrait, smooth skin, professional lighting, animated character",
        "sketch": "monochrome portrait in pencil sketch style, grayscale face art, charcoal portrait aesthetic, line art face, head and shoulders only",
        "watercolor": "watercolor portrait art style, painted face effect, soft artistic rendering, pastel portrait"
    }

    negative_prompts = {
        "anime": "hands, arms, fingers, body, torso, pencils, pens, brushes, tools, objects, items, sketchbook, notebook, paper, canvas, easel, drawing hand, artist hand, holding, watermark, text, signature, logo, frame, border, multiple people, ugly, deformed, blurry, low quality",
        "comic": "hands, arms, fingers, body, torso, pencils, pens, brushes, tools, objects, items, sketchbook, notebook, paper, canvas, easel, drawing hand, artist hand, holding, watermark, text, signature, logo, frame, border, multiple people, ugly, deformed, blurry, low quality",
        "pixar": "hands, arms, fingers, body, torso, pencils, pens, brushes, tools, objects, items, sketchbook, notebook, paper, canvas, easel, drawing hand, artist hand, holding, watermark, text, signature, logo, frame, border, multiple people, ugly, deformed, blurry, low quality",
        "sketch": "(hands:1.5), (fingers:1.5), (pencil:2.0), (pen:2.0), (artist hand:2.0), (holding:2.0), arms, body, torso, drawing pencils, graphite pencil, colored pencils, mechanical pencil, charcoal stick, brushes, erasers, tools, objects, sketchbook, spiral notebook, notebook, paper background, paper texture, canvas, easel, artist, drawing process, meta, holding pencil, holding pen, holding anything, drawing hand, hand drawing, items, watermark, text, signature, logo, frame, border, multiple people, photograph, photo, realistic, ugly, deformed, blurry, low quality, bad anatomy, extra limbs",
        "watercolor": "(hands:1.5), (fingers:1.5), (paintbrush:2.0), (brush:2.0), (artist hand:2.0), (holding:2.0), arms, body, torso, painting tools, pencils, pens, palette, paint tubes, paint palette, water cup, canvas, easel, paper, artist, painting process, holding brush, holding anything, drawing hand, objects, items, watermark, text, signature, logo, frame, border, multiple people, ugly, deformed, blurry, low quality"
    }
    
    style = params.get("style", "anime").lower()
    prompt = presets.get(style, presets["anime"])
    negative_prompt = negative_prompts.get(style, negative_prompts["anime"])

    if params.get("prompt_extra"):
        prompt = f"{prompt}, {params['prompt_extra']}"

    img = prepare_image(params["input_path"], params.get("max_resolution", 768))

    generator = None
    if params.get("seed", -1) >= 0:
        generator = torch.Generator(device=actual_device).manual_seed(params["seed"])

    log("Generating...")
    try:
        output = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=img,
            strength=params.get("strength", 0.6),
            guidance_scale=params.get("guidance_scale", 7.5),
            num_inference_steps=params.get("steps", 30),
            generator=generator
        ).images[0]
        log("Complete!")
    except Exception as e:
        log(f"Generation failed: {e}")
        raise
    
    scale = params.get("output_scale", 1.0)
    if scale != 1.0:
        output = output.resize((int(output.width * scale), int(output.height * scale)), Image.LANCZOS)
    
    if params.get("export_format", "png") == "jpeg":
        output.save(params["output_path"], format="JPEG", quality=params.get("jpeg_quality", 90))
    else:
        output.save(params["output_path"], format="PNG")
    return params["output_path"]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--params", required=True)
    args = parser.parse_args()

    try:
        # Set signal handlers to catch crashes
        import signal
        def signal_handler(sig, frame):
            log(f"Received signal {sig}, exiting gracefully")
            sys.exit(1)
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)

        with open(args.params) as f:
            params = json.load(f)
        result = cartoonize(params)
        print(json.dumps({"success": True, "output_path": result}), flush=True)
    except KeyboardInterrupt:
        log("Interrupted by user")
        sys.exit(1)
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}"
        log(f"Error: {error_msg}")
        print(json.dumps({"success": False, "error": error_msg}), file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    # Ensure output is flushed immediately
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)
    main()
"""
        
        let scriptPath = scriptsURL.appendingPathComponent("cartoonizer_cli.py")
        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
        
        let attrs = [FileAttributeKey.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: scriptPath.path)
    }
    
    func generate(params: GenerationParameters, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Verify Python executable exists
                guard FileManager.default.fileExists(atPath: self.pythonExecutable.path) else {
                    print("[PythonBridge] ERROR: Python executable not found at \(self.pythonExecutable.path)")
                    completion(.failure(PythonBridgeError.pythonNotFound))
                    return
                }

                // Create temp directory for input images
                let tempDir = self.appSupportURL.appendingPathComponent("temp", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let outputDir = self.appSupportURL.appendingPathComponent("outputs", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let timestamp = Int(Date().timeIntervalSince1970)

                // Copy input file to app support directory to avoid sandboxing issues
                let inputURL = URL(fileURLWithPath: params.inputPath)
                let tempInputURL = tempDir.appendingPathComponent("input_\(timestamp).\(inputURL.pathExtension)")
                try FileManager.default.copyItem(at: inputURL, to: tempInputURL)

                let ext = params.exportFormat == "png" ? "png" : "jpg"
                let outputPath = outputDir.appendingPathComponent("cartoon_\(timestamp).\(ext)").path

                // Build params dict - using the copied input path
                let paramsDict: [String: Any] = [
                    "input_path": tempInputURL.path,
                    "output_path": outputPath,
                    "style": params.style,
                    "prompt_extra": params.promptExtra,
                    "strength": params.strength,
                    "guidance_scale": params.guidanceScale,
                    "steps": params.steps,
                    "seed": params.seed,
                    "max_resolution": params.maxResolution,
                    "output_scale": params.outputScale,
                    "export_format": params.exportFormat,
                    "jpeg_quality": params.jpegQuality,
                    "model_id": "Lykon/dreamshaper-8",  // Default model
                    "force_cpu": true  // Use CPU for now - subprocess fork issue with MPS
                ]
                
                let paramsData = try JSONSerialization.data(withJSONObject: paramsDict)
                let paramsPath = self.scriptsURL.appendingPathComponent("params_\(timestamp).json")
                try paramsData.write(to: paramsPath)

                // Choose script based on Core ML availability
                let useCoreML = self.hasCoreMLModels()
                let scriptName = useCoreML ? "cartoonizer_coreml.py" : "cartoonizer_cli.py"
                let scriptPath = self.scriptsURL.appendingPathComponent(scriptName)

                // Verify script exists
                if !FileManager.default.fileExists(atPath: scriptPath.path) {
                    print("[PythonBridge] ERROR: Script not found at \(scriptPath.path)")
                    print("[PythonBridge] Attempting to create script...")
                    try self.copyPythonScripts()
                    if !FileManager.default.fileExists(atPath: scriptPath.path) {
                        print("[PythonBridge] ERROR: Failed to create script")
                        completion(.failure(PythonBridgeError.generationFailed("Python script not found")))
                        return
                    }
                }

                if useCoreML {
                    print("[PythonBridge] Using Core ML models for faster generation!")
                } else {
                    print("[PythonBridge] Core ML models not found, using CPU mode")
                    print("[PythonBridge] Run download_coreml_models.py for 20-40x speedup")
                }

                print("[PythonBridge] Script path: \(scriptPath.path)")
                print("[PythonBridge] Python executable: \(self.pythonExecutable.path)")
                print("[PythonBridge] Input image: \(tempInputURL.path)")
                print("[PythonBridge] Output path: \(outputPath)")
                print("[PythonBridge] Params file: \(paramsPath.path)")

                let process = Process()
                process.executableURL = self.pythonExecutable
                process.arguments = [
                    scriptPath.path,
                    "--params", paramsPath.path
                ]

                let fullCommand = "\(self.pythonExecutable.path) \(process.arguments?.joined(separator: " ") ?? "")"
                print("[PythonBridge] Executing command: \(fullCommand)")
                
                var env = ProcessInfo.processInfo.environment
                env["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"
                env["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
                env["PYTORCH_MPS_HIGH_WATERMARK_RATIO"] = "0.0"
                env["PYTHONUNBUFFERED"] = "1"
                env["OMP_NUM_THREADS"] = "4"
                env["MKL_NUM_THREADS"] = "4"
                env["OPENBLAS_NUM_THREADS"] = "4"
                env["TOKENIZERS_PARALLELISM"] = "false"
                process.environment = env
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                var outputData = Data()
                var errorData = Data()
                
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputData.append(data)
                        if let str = String(data: data, encoding: .utf8) {
                            print("[Python] \(str)", terminator: "")
                        }
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        errorData.append(data)
                    }
                }
                
                try process.run()
                process.waitUntilExit()
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                // Cleanup temporary files
                try? FileManager.default.removeItem(at: paramsPath)
                try? FileManager.default.removeItem(at: tempInputURL)

                let fullOutput = String(data: outputData, encoding: .utf8) ?? ""
                let fullError = String(data: errorData, encoding: .utf8) ?? ""

                print("[PythonBridge] Process exit code: \(process.terminationStatus)")
                print("[PythonBridge] Full output: \(fullOutput)")
                print("[PythonBridge] Full error: \(fullError)")

                if process.terminationStatus == 0 {
                    if let jsonLine = fullOutput.components(separatedBy: "\n").last(where: { $0.contains("{") }),
                       let jsonData = jsonLine.data(using: .utf8),
                       let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let success = result["success"] as? Bool, success,
                       let resultPath = result["output_path"] as? String {
                        completion(.success(resultPath))
                        return
                    }
                    let errorMsg = "Invalid output format. Output: \(fullOutput.prefix(500))"
                    print("[PythonBridge] \(errorMsg)")
                    completion(.failure(PythonBridgeError.invalidOutput))
                } else {
                    let errorMsg = fullError.isEmpty ? "Process failed with exit code \(process.terminationStatus)" : fullError
                    print("[PythonBridge] Generation failed: \(errorMsg)")
                    completion(.failure(PythonBridgeError.generationFailed(errorMsg)))
                }
            } catch {
                print("[PythonBridge] Exception caught: \(error)")
                print("[PythonBridge] Error description: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("[PythonBridge] Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("[PythonBridge] Error userInfo: \(nsError.userInfo)")
                }
                completion(.failure(error))
            }
        }
    }
}
