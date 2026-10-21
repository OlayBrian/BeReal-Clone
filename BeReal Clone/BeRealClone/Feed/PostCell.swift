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
    private let blurView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemChromeMaterialDark)
    )
    private let blurMessageLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .black
        contentView.backgroundColor = .black
        usernameLabel.textColor = .white
        captionLabel.textColor = .white
        dateLabel.textColor = .white
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        postImageView.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: postImageView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: postImageView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: postImageView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: postImageView.bottomAnchor)
        ])

        blurMessageLabel.text = "This post is blurred because it is over 24 hours old"
        blurMessageLabel.textColor = .white
        blurMessageLabel.font = .preferredFont(forTextStyle: .headline)
        blurMessageLabel.adjustsFontForContentSizeCategory = true
        blurMessageLabel.textAlignment = .center
        blurMessageLabel.numberOfLines = 0
        blurMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(blurMessageLabel)
        NSLayoutConstraint.activate([
            blurMessageLabel.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            blurMessageLabel.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            blurMessageLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: blurView.contentView.leadingAnchor,
                constant: 24
            ),
            blurMessageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: blurView.contentView.trailingAnchor,
                constant: -24
            )
        ])
    }

    func configure(with post: Post, isImageBlurred: Bool) {
        // TODO: Pt 1 - Configure Post Cell
        // Username
        usernameLabel.text = post.user?.username ?? post.username ?? "Unknown user"
        blurView.isHidden = !isImageBlurred
        postImageView.accessibilityLabel = isImageBlurred
            ? "Post image blurred because it is outside your viewing window"
            : "Post image"
        
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
        usernameLabel.text = nil
        captionLabel.text = nil
        dateLabel.text = nil

        // Cancel image request.
        imageDataRequest?.cancel()
        
    }
}
