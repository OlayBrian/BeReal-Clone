import Photos
import UIKit

final class PhotoLibraryManager {
    static let shared = PhotoLibraryManager()

    private init() {}

    func save(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                let error = NSError(
                    domain: "PhotoLibraryManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Photo Library access was not allowed."]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let saveError = error ?? NSError(
                            domain: "PhotoLibraryManager",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "The photo could not be saved."]
                        )
                        completion(.failure(saveError))
                    }
                }
            }
        }
    }
}
