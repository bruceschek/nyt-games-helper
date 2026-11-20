import SwiftUI
import UIKit

/// A picture of a puzzle, turned the right way up.
///
/// Camera photos are stored sideways with a tag saying which way to turn them.
/// Redrawing them upright once, here, means every later step — Vision's boxes,
/// cutting hexagons out of the pixels — can take the pixels at face value.
struct PuzzlePhoto {
    let image: CGImage

    init(image: CGImage) { self.image = image }

    init?(_ uiImage: UIImage) {
        if uiImage.imageOrientation == .up, let cgImage = uiImage.cgImage {
            image = cgImage
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = uiImage.scale
        let upright = UIGraphicsImageRenderer(size: uiImage.size, format: format).image { _ in
            uiImage.draw(at: .zero)
        }
        guard let cgImage = upright.cgImage else { return nil }
        image = cgImage
    }

    init?(data: Data) {
        guard let uiImage = UIImage(data: data) else { return nil }
        self.init(uiImage)
    }
}

/// The system camera, for photographing a puzzle on another screen. SwiftUI has
/// no camera view of its own, so this wraps UIKit's.
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
