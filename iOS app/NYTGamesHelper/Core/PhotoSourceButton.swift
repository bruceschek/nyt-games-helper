import Photos
import PhotosUI
import SwiftUI

/// The camera button every game that reads pictures shares: the latest
/// screenshot in one tap, any picture from Photos, or a photo of another screen.
///
/// Latest Screenshot is the quick path when the game is played on this same phone
/// — screenshot it, switch over, tap. Over a Wordle game that's once per guess.
struct PhotoSourceButton<Label: View>: View {
    var isReading = false
    let onPhoto: (PuzzlePhoto) -> Void
    var onProblem: (PuzzleInputError) -> Void = { _ in }
    @ViewBuilder var label: () -> Label

    @State private var showingPicker = false
    @State private var showingCamera = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        Menu {
            Button("Latest Screenshot", systemImage: "camera.viewfinder") {
                Task {
                    switch await LatestScreenshot.load() {
                    case .success(let photo): onPhoto(photo)
                    case .failure(let problem): onProblem(problem)
                    }
                }
            }
            Button("Choose from Photos", systemImage: "photo.on.rectangle") {
                showingPicker = true
            }
            if CameraView.isAvailable {
                Button("Take a Photo", systemImage: "camera") {
                    showingCamera = true
                }
            }
        } label: {
            if isReading { ProgressView() } else { label() }
        }
        .disabled(isReading)
        .photosPicker(isPresented: $showingPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let photo = PuzzlePhoto(data: data) {
                    onPhoto(photo)
                } else {
                    onProblem(PuzzleInputError("I couldn't open that picture."))
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                if let photo = PuzzlePhoto(image) { onPhoto(photo) }
            }
            .ignoresSafeArea()
        }
    }
}

/// The newest screenshot in the photo library.
enum LatestScreenshot {
    static func load() async -> Result<PuzzlePhoto, PuzzleInputError> {
        let access = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard access == .authorized || access == .limited else {
            return .failure(PuzzleInputError("To use your latest screenshot, allow access to Photos in Settings → Apps → NYT Games."))
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0",
                                        PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else {
            return .failure(PuzzleInputError(access == .limited
                ? "I can only see the photos you've shared with this app, and there's no screenshot among them. Allow full access in Settings, or choose the screenshot instead."
                : "There are no screenshots in your photo library yet."))
        }

        let request = PHImageRequestOptions()
        request.deliveryMode = .highQualityFormat
        request.isNetworkAccessAllowed = true
        request.version = .current
        let data: Data? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data, let photo = PuzzlePhoto(data: data) else {
            return .failure(PuzzleInputError("I couldn't open your latest screenshot."))
        }
        return .success(photo)
    }
}
