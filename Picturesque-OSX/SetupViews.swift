//
//  SetupViews.swift
//  Picturesque Native
//

import SwiftUI

// MARK: - Setup Coordinator View
struct SetupCoordinatorView: View {
    @ObservedObject var setupManager: SetupManager
    @Binding var showingSetup: Bool
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.09),
                    Color(red: 0.08, green: 0.08, blue: 0.12)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                SetupHeaderView()
                
                // Main Content
                if setupManager.isSetupComplete {
                    SetupCompleteView(showingSetup: $showingSetup)
                } else {
                    TabView(selection: $setupManager.currentStep) {
                        EnvironmentSetupView(setupManager: setupManager)
                            .tag(SetupStep.virtualEnvironment)
                        
                        ModelManagementView(setupManager: setupManager)
                            .tag(SetupStep.modelManagement)
                    }
                    .tabViewStyle(.automatic)
                }
                
                // Logs
                SetupLogsView(logs: setupManager.setupLogs)
                    .frame(height: 150)
            }
        }
        .onAppear {
            if setupManager.virtualEnvStatus == .notStarted {
                setupManager.startSetup()
            }
        }
    }
}

// MARK: - Header
struct SetupHeaderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.99, green: 0.83, blue: 0.63),
                    Color(red: 0.98, green: 0.55, blue: 0.42),
                    Color(red: 0.28, green: 0.15, blue: 0.47)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SETUP REQUIRED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(Color(red: 0.07, green: 0.06, blue: 0.09))
                
                Text("Picturesque Setup")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.07, green: 0.06, blue: 0.09))
                
                Text("Let's get your AI cartoon generator ready!")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.07, green: 0.06, blue: 0.09).opacity(0.8))
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Environment Setup View
struct EnvironmentSetupView: View {
    @ObservedObject var setupManager: SetupManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.61))
            
            // Status
            VStack(spacing: 12) {
                Text("Setting Up Python Environment")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                switch setupManager.virtualEnvStatus {
                case .notStarted:
                    Text("Preparing to start...")
                        .foregroundColor(.white.opacity(0.6))
                    
                case .inProgress(_, let message):
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(message)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                case .completed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Environment ready!")
                            .foregroundColor(.white)
                    }
                    
                case .failed(let error):
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Setup failed")
                                .foregroundColor(.white)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Button("Retry Setup") {
                            setupManager.startSetup()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top)
                    }
                }
            }
            
            Spacer()
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "timer", text: "First-time setup takes ~5-10 minutes")
                InfoRow(icon: "arrow.down.circle", text: "Downloads ~500 MB of AI libraries")
                InfoRow(icon: "checkmark.shield", text: "Everything runs locally on your Mac")
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Model Management View
struct ModelManagementView: View {
    @ObservedObject var setupManager: SetupManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.61))
                    
                    Text("AI Models")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Download at least one model to start creating")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        setupManager.downloadAllMissingModels()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download All Missing")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 1.0, green: 0.82, blue: 0.61))
                        )
                        .foregroundColor(.black)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(setupManager.availableModels.allSatisfy { $0.isDownloaded || $0.isDownloading })
                    
                    Button(action: {
                        setupManager.checkDownloadedModels()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 10)
                
                // Model List
                VStack(spacing: 12) {
                    ForEach(setupManager.availableModels) { model in
                        ModelCardView(model: model) {
                            setupManager.downloadModel(modelId: model.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 30)
            }
        }
    }
}

// MARK: - Model Card
struct ModelCardView: View {
    let model: ModelInfo
    let onDownload: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(model.isDownloaded ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                
                Image(systemName: model.isDownloaded ? "checkmark.circle.fill" : "cube.fill")
                    .font(.system(size: 28))
                    .foregroundColor(model.isDownloaded ? .green : .white.opacity(0.5))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(model.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(model.size)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    
                    if model.isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Downloaded")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            if model.isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("\(Int(model.downloadProgress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 60)
            } else if !model.isDownloaded {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.61))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(model.isDownloaded ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Setup Complete View
struct SetupCompleteView: View {
    @Binding var showingSetup: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            // Message
            VStack(spacing: 12) {
                Text("Setup Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your AI cartoon generator is ready to use")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Start Button
            Button(action: {
                showingSetup = false
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Start Creating")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: 300)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.82, blue: 0.61),
                                    Color(red: 0.98, green: 0.55, blue: 0.42)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.black)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Logs View
struct SetupLogsView: View {
    let logs: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Setup Log")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .onChange(of: logs.count) { _ in
                        if let lastIndex = logs.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.2))
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.61))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
