//
//  PostCell.swift
//  BeReal Clone
//
//  Created by Brian Ribeiro on 11/3/22.
//

import UIKit
import Alamofire
import AlamofireImage
import CoreLocation

class PostCell: UITableViewCell {

    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var postImageView: UIImageView!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    private var imageDataRequest: DataRequest?

    func configure(with post: Post) {
        // TODO: Pt 1 - Configure Post Cell
        // Username
        if let user = post.user {
            usernameLabel.text = user.username
        }
        
        // Image
        if let imageFile = post.imageFile,
           let imageUrl = imageFile.url {
            
            // Use AlamofireImage helper to fetch remote image from URL
            imageDataRequest = AF.request(imageUrl).responseImage { [weak self] response in
                switch response.result {
                case .success(let image):
                    // Set image view image with fetched image
                    self?.postImageView.image = image
                case .failure(let error):
                    print("❌ Error fetching image: \(error.localizedDescription)")
                    break
                    
                }
            }
        }
        
        // Caption
        captionLabel.text = post.caption
        
        // Date
        if let date = post.createdAt {
            dateLabel.text = DateFormatter.postFormatter.string(from: date)
        }
        
        if let location = post.location {
            let clLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            CLGeocoder().reverseGeocodeLocation(clLocation) { [weak self] placemarks, error in
                guard let placemark = placemarks?.first else { return }
                
                let city = placemark.locality
                let state = placemark.administrativeArea
                
                DispatchQueue.main.async {
                    if let city = city, let state = state {
                        self?.dateLabel.text = "\(self?.dateLabel.text ?? "") • \(city), \(state)"
                    } else if let city = city {
                        self?.dateLabel.text = "\(self?.dateLabel.text ?? "") • \(city)"
                    }
                }
            }
        }
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        // TODO: P1 - Cancel image download
        // Reset image view image.
        postImageView.image = nil

        // Cancel image request.
        imageDataRequest?.cancel()
        
    }
}
