//
//  ContentView.swift
//  Picturesque-OSX
//
//  Modern, clean UI redesign
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = PicturesqueViewModel()
    @State private var selectedTab: Tab = .transform

    enum Tab {
        case transform, settings
    }

    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Modern Header
                ModernHeader()

                // Main Content Area
                GeometryReader { geometry in
                    HStack(spacing: 24) {
                        // Left Sidebar - Controls
                        ControlSidebar(viewModel: viewModel)
                            .frame(width: 320)

                        // Center - Image Workspace
                        ImageWorkspace(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            viewModel.initialize()
        }
    }
}

// MARK: - Modern Header
struct ModernHeader: View {
    var body: some View {
        HStack {
            // Logo/Title
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.6, green: 0.4, blue: 1.0),
                                Color(red: 0.4, green: 0.6, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Picturesque")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("AI Studio")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("Neural Engine Ready")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            Color.black.opacity(0.2)
                .blur(radius: 20)
        )
    }
}

// MARK: - Control Sidebar
struct ControlSidebar: View {
    @ObservedObject var viewModel: PicturesqueViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // Upload Section
                UploadCard(viewModel: viewModel)

                // Style Selection
                StyleCard(viewModel: viewModel)

                // Advanced Settings
                SettingsCard(viewModel: viewModel)

                // Generate Button
                GenerateCard(viewModel: viewModel)

                // Output Log
                OutputLogCard(viewModel: viewModel)

                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - Upload Card
struct UploadCard: View {
    @ObservedObject var viewModel: PicturesqueViewModel
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 12) {
            // Card Header
            HStack {
                Text("Upload Image")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            // Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isDragging ?
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    )

                if let image = viewModel.inputImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.white.opacity(0.3))

                        Text("Drop image or")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Button(action: { viewModel.selectImage() }) {
                            Text("Browse Files")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(height: 100)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data,
                          let path = String(data: data, encoding: .utf8),
                          let url = URL(string: path) else { return }
                    DispatchQueue.main.async {
                        viewModel.loadImage(from: url)
                    }
                }
                return true
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

// MARK: - Style Card
struct StyleCard: View {
    @ObservedObject var viewModel: PicturesqueViewModel

    let styles = ["Anime", "Comic", "Pixar", "Sketch", "Watercolor"]
    let styleIcons = ["sparkles", "book.fill", "moon.stars.fill", "pencil.line", "paintbrush.fill"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Art Style")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
                    StyleButton(
                        title: style,
                        icon: styleIcons[index],
                        isSelected: viewModel.selectedStyle == style,
                        action: { viewModel.selectedStyle = style }
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

struct StyleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.3, blue: 0.9),
                                    Color(red: 0.3, green: 0.5, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Card
struct SettingsCard: View {
    @ObservedObject var viewModel: PicturesqueViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }}) {
                HStack {
                    Text("Advanced Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 16) {
                    SettingSlider(
                        title: "Strength",
                        value: $viewModel.strength,
                        range: 0...1,
                        step: 0.05
                    )

                    SettingSlider(
                        title: "Guidance",
                        value: $viewModel.guidanceScale,
                        range: 1...20,
                        step: 0.5
                    )

                    SettingSlider(
                        title: "Steps",
                        value: $viewModel.steps,
                        range: 20...50,
                        step: 1
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text(String(format: "%.2f", value))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
                .tint(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Generate Card
struct GenerateCard: View {
    @ObservedObject var viewModel: PicturesqueViewModel

    var body: some View {
        VStack(spacing: 10) {
            Button(action: { viewModel.generate() }) {
                HStack(spacing: 12) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(viewModel.isProcessing ? "Generating..." : "Generate")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            viewModel.inputImage == nil || viewModel.isProcessing ?
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.3, blue: 0.9),
                                        Color(red: 0.3, green: 0.5, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .shadow(
                            color: viewModel.inputImage != nil && !viewModel.isProcessing ?
                                Color.purple.opacity(0.5) : .clear,
                            radius: 15,
                            y: 5
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.inputImage == nil || viewModel.isProcessing)

            // Progress Bar - Always visible
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.generationProgress, height: 4)
                            .animation(.linear(duration: 0.3), value: viewModel.generationProgress)
                    }
                }
                .frame(height: 4)

                if !viewModel.currentStage.isEmpty {
                    Text(viewModel.currentStage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

// MARK: - Output Log Card
struct OutputLogCard: View {
    @ObservedObject var viewModel: PicturesqueViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 8) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }}) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text("Output Log")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.statusMessages, id: \.self) { message in
                            Text(message)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

// MARK: - Image Workspace
struct ImageWorkspace: View {
    @ObservedObject var viewModel: PicturesqueViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 20) {
                WorkspaceTab(title: "Input", isActive: viewModel.inputImage != nil)
                WorkspaceTab(title: "Output", isActive: viewModel.outputImage != nil)

                Spacer()

                if viewModel.outputImage != nil {
                    Button(action: { viewModel.saveOutput() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                            Text("Export")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.02))

            // Image Display
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Input Image
                    ImagePreviewPane(
                        image: viewModel.inputImage,
                        label: "Original",
                        geometry: geometry
                    )

                    // Divider
                    if viewModel.inputImage != nil && viewModel.outputImage != nil {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1)
                    }

                    // Output Image
                    if viewModel.outputImage != nil {
                        ImagePreviewPane(
                            image: viewModel.outputImage,
                            label: "Cartoonized",
                            geometry: geometry
                        )
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.02))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }
}

struct WorkspaceTab: View {
    let title: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? .white : .white.opacity(0.4))

            if isActive {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .transition(.scale)
            }
        }
    }
}

struct ImagePreviewPane: View {
    let image: NSImage?
    let label: String
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.2))

                    Text("No \(label.lowercased()) image")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1400, height: 900)
}
