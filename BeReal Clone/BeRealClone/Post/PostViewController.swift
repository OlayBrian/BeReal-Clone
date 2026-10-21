//
//  PostViewController.swift
//  BeReal Clone
//
//  Created by Brian Ribeiro on 11/1/22.
//

import UIKit

import Photos
import CoreLocation

// TODO: Import Photos UI
import PhotosUI
// TODO: Import Parse Swift
import ParseSwift

class PostViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var captionTextField: UITextField!
    @IBOutlet weak var previewImageView: UIImageView!
    

    private var pickedImage: UIImage?
    private var pickedLocation: CLLocation?
    private let locationManager = CLLocationManager()
    private var isWaitingForPhotoLocation = false

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    @IBAction func onPickedImageTapped(_ sender: UIBarButtonItem) {
        let sourcePicker = UIAlertController(
            title: "Add a photo",
            message: nil,
            preferredStyle: .actionSheet
        )

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sourcePicker.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }

        sourcePicker.addAction(UIAlertAction(title: "Choose from Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        sourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sourcePicker.popoverPresentationController?.barButtonItem = sender
        present(sourcePicker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(description: "The camera is not available on this device.")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentPhotoLibrary() {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction func onShareTapped(_ sender: Any) {

        // Dismiss Keyboard
        view.endEditing(true)

        // TODO: Pt 1 - Create and save Post
        // Unwrap optional pickedImage
        guard let image = pickedImage,
              // Create and compress image data (jpeg) from UIImage
              let imageData = image.jpegData(compressionQuality: 0.1) else {
            return
        }

        // Create a Parse File by providing a name and passing in the image data
        let imageFile = ParseFile(name: "image.jpg", data: imageData)

        // Create Post object
        var post = Post()

        // Set properties
        post.imageFile = imageFile
        post.caption = captionTextField.text

        // Set the user as the current user
        post.user = User.current
        post.username = User.current?.username
        
        if let pickedLocation = pickedLocation {
            post.location = try? ParseGeoPoint(location: pickedLocation)
        }
        
        // Save object in background (async)
        post.save { [weak self] result in

            // Switch to the main thread for any UI updates
            DispatchQueue.main.async {
                switch result {
                case .success(let post):
                    print("✅ Post Saved! \(post)")

                    PhotoLibraryManager.shared.save(image, location: self?.pickedLocation) { saveResult in
                        if case .failure(let error) = saveResult {
                            print("❌ Photo Library save error: \(error.localizedDescription)")
                        }

                        // Return to previous view controller after the save attempt finishes.
                        self?.navigationController?.popViewController(animated: true)
                    }

                case .failure(let error):
                    self?.showAlert(description: error.localizedDescription)
                }
            }
        }

    }

    @IBAction func onViewTapped(_ sender: Any) {
        // Dismiss keyboard
        view.endEditing(true)
    }

    private func requestLocationForCapturedPhoto() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isWaitingForPhotoLocation = false
            shareButton.isEnabled = true
            showAlert(description: "Location access is off. Enable it in Settings to add a location to camera photos.")
        @unknown default:
            isWaitingForPhotoLocation = false
            shareButton.isEnabled = true
        }
    }

    private func showAlert(description: String? = nil) {
        let alertController = UIAlertController(title: "Oops...", message: "\(description ?? "Please try again...")", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        present(alertController, animated: true)
    }
}

extension PostViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isWaitingForPhotoLocation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isWaitingForPhotoLocation = false
            shareButton.isEnabled = true
            showAlert(description: "Location access is off. Enable it in Settings to add a location to camera photos.")
        case .notDetermined:
            break
        @unknown default:
            isWaitingForPhotoLocation = false
            shareButton.isEnabled = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isWaitingForPhotoLocation, let location = locations.last else { return }

        pickedLocation = location
        isWaitingForPhotoLocation = false
        shareButton.isEnabled = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isWaitingForPhotoLocation else { return }

        isWaitingForPhotoLocation = false
        shareButton.isEnabled = true
        showAlert(description: "Your location could not be determined. You can still share the photo.")
    }
}

extension PostViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            showAlert(description: "The photo could not be loaded.")
            return
        }

        pickedImage = image
        pickedLocation = nil
        previewImageView.image = image
        shareButton.isEnabled = false
        isWaitingForPhotoLocation = true
        picker.dismiss(animated: true) { [weak self] in
            self?.requestLocationForCapturedPhoto()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// TODO: Pt 1 - Add PHPickerViewController delegate and handle picked image.
extension PostViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Dismiss the picker
        picker.dismiss(animated: true)

        // Make sure we have a non-nil item provider
        guard let provider = results.first?.itemProvider,
           // Make sure the provider can load a UIImage
           provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        let result = results.first

        if let assetId = result?.assetIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            pickedLocation = assets.firstObject?.location
        }

        // Load a UIImage from the provider
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in

           // Make sure we can cast the returned object to a UIImage
           guard let image = object as? UIImage else {

              // ❌ Unable to cast to UIImage
              self?.showAlert()
              return
           }

           // Check for and handle any errors
           if let error = error {
               self?.showAlert(description: error.localizedDescription)
              return
           } else {

              // UI updates (like setting image on image view) should be done on main thread
              DispatchQueue.main.async {

                 // Set image on preview image view
                 self?.previewImageView.image = image

                 // Set image to use when saving post
                 self?.pickedImage = image
              }
           }
        }
    }
    

}

