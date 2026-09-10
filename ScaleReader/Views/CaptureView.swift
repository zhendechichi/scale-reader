import SwiftUI
import UIKit
import PhotosUI

/// “拍照记录”页：按屏幕顺序拍多张照片 → AI 识别 → 确认保存。
struct CaptureView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var images: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var pendingReading: ScaleReading?

    private let maxImages = 12

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tipCard

                    if images.isEmpty {
                        emptyHint
                    } else {
                        photoGrid
                    }

                    addButtons

                    recognizeButton

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("AI 识别中，请稍候…")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("拍照记录")
            .toolbar {
                if !images.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空") { images.removeAll() }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    appendIfRoom(image)
                }
                .ignoresSafeArea()
            }
            .sheet(item: $pendingReading) { reading in
                ResultEditView(reading: reading)
            }
            .onChange(of: pickerItems) { _ in
                Task { await loadPickedImages() }
            }
        }
    }

    // MARK: - 子视图

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("怎么用", systemImage: "lightbulb.fill")
                .font(.headline)
            Text("站上体脂秤完成测量，然后按顺序一屏拍一张（顺序很重要，共约 10 屏）：\n体重 → 体脂肪率 → 身体年龄 → BMI → 基础代谢 → 内脏脂肪 → 全身 → 双臂 → 躯干 → 双脚。\n拍照时让屏幕尽量占满画面、避免反光（小数点才看得清）；屏幕会自动熄灭，请连着拍。拍完点“开始 AI 识别”。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text("还没有照片\n拍照或从相册选择屏幕照片")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
            ForEach(images.indices, id: \.self) { idx in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: images[idx])
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        images.remove(at: idx)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .padding(4)
                }
            }
        }
    }

    private var addButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            PhotosPicker(selection: $pickerItems, maxSelectionCount: maxImages - images.count, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(images.count >= maxImages)
        }
        .controlSize(.large)
    }

    private var recognizeButton: some View {
        Button {
            startRecognition()
        } label: {
            Label(images.isEmpty ? "开始 AI 识别" : "开始 AI 识别（\(images.count) 张）",
                  systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(images.isEmpty || isLoading)
    }

    // MARK: - 逻辑

    private func appendIfRoom(_ image: UIImage) {
        guard images.count < maxImages else { return }
        images.append(image)
    }

    private func loadPickedImages() async {
        for item in pickerItems {
            guard images.count < maxImages else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        pickerItems.removeAll()
    }

    private func startRecognition() {
        guard !images.isEmpty else { return }
        guard let key = settings.apiKey, !key.isEmpty else {
            errorText = "还没有配置 API Key，请先到“设置”页填写并保存。"
            return
        }
        errorText = nil
        isLoading = true
        let config = AIConfig(baseURL: settings.apiBaseURL, model: settings.apiModel, apiKey: key)
        Task {
            do {
                let reading = try await AIService().readReading(images: images, config: config)
                pendingReading = reading
            } catch {
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }
}

/// 系统相机封装（UIImagePickerController）。
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
