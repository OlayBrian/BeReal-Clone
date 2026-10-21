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
    @IBOutlet private weak var contentStackView: UIStackView!
    private var imageDataRequest: DataRequest?
    private let geocoder = CLGeocoder()
    private var representedPostId: String?
    private var baseDateText = ""
    private let commentsStackView = UIStackView()
    private let addCommentButton = UIButton(type: .system)
    private let savePhotoButton = UIButton(type: .system)
    private var onAddComment: (() -> Void)?
    private var onSavePhoto: ((UIImage) -> Void)?
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

        commentsStackView.axis = .vertical
        commentsStackView.spacing = 4
        commentsStackView.isLayoutMarginsRelativeArrangement = true
        commentsStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 4,
            leading: 16,
            bottom: 0,
            trailing: 16
        )
        contentStackView.addArrangedSubview(commentsStackView)

        addCommentButton.setTitle("Add Comment", for: .normal)
        addCommentButton.contentHorizontalAlignment = .leading
        addCommentButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        addCommentButton.titleLabel?.adjustsFontForContentSizeCategory = true
        addCommentButton.addTarget(self, action: #selector(addCommentTapped), for: .touchUpInside)
        contentStackView.addArrangedSubview(addCommentButton)

        savePhotoButton.setTitle("Save Photo", for: .normal)
        savePhotoButton.contentHorizontalAlignment = .leading
        savePhotoButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        savePhotoButton.titleLabel?.adjustsFontForContentSizeCategory = true
        savePhotoButton.addTarget(self, action: #selector(savePhotoTapped), for: .touchUpInside)
        contentStackView.addArrangedSubview(savePhotoButton)
        contentStackView.setCustomSpacing(16, after: savePhotoButton)
    }

    func configure(
        with post: Post,
        comments: [Comment],
        isImageBlurred: Bool,
        onAddComment: @escaping () -> Void,
        onSavePhoto: @escaping (UIImage) -> Void
    ) {
        representedPostId = post.objectId
        geocoder.cancelGeocode()

        // TODO: Pt 1 - Configure Post Cell
        // Username
        usernameLabel.text = post.user?.username ?? post.username ?? "Unknown user"
        blurView.isHidden = !isImageBlurred
        postImageView.accessibilityLabel = isImageBlurred
            ? "Post image blurred because it is over 24 hours old"
            : "Post image"
        self.onAddComment = onAddComment
        self.onSavePhoto = onSavePhoto
        savePhotoButton.isEnabled = !isImageBlurred
        savePhotoButton.alpha = isImageBlurred ? 0.5 : 1
        configureComments(comments)
        
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
        baseDateText = post.createdAt.map {
            DateFormatter.postFormatter.string(from: $0)
        } ?? ""
        dateLabel.text = baseDateText
        
        if let location = post.location {
            let postId = post.objectId
            let clLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            geocoder.reverseGeocodeLocation(clLocation) { [weak self] placemarks, error in
                guard let self = self,
                      self.representedPostId == postId,
                      let placemark = placemarks?.first else { return }
                
                let locationText: String?
                if let city = placemark.locality,
                   let state = placemark.administrativeArea {
                    locationText = "\(city), \(state)"
                } else {
                    locationText = placemark.locality
                }
                
                DispatchQueue.main.async {
                    guard self.representedPostId == postId else { return }
                    self.dateLabel.text = [self.baseDateText, locationText]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")
                }
            }
        }
    }
    private func configureComments(_ comments: [Comment]) {
        commentsStackView.arrangedSubviews.forEach { view in
            commentsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for comment in comments {
            let label = UILabel()
            let username = comment.user?.username ?? comment.username ?? "Unknown user"
            label.text = "\(username): \(comment.text ?? "")"
            label.textColor = .white
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            commentsStackView.addArrangedSubview(label)
        }
    }

    @objc private func addCommentTapped() {
        onAddComment?()
    }

    @objc private func savePhotoTapped() {
        guard let image = postImageView.image else { return }
        onSavePhoto?(image)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        // TODO: P1 - Cancel image download
        // Reset image view image.
        postImageView.image = nil
        usernameLabel.text = nil
        captionLabel.text = nil
        dateLabel.text = nil
        representedPostId = nil
        baseDateText = ""
        geocoder.cancelGeocode()
        onAddComment = nil
        onSavePhoto = nil
        savePhotoButton.isEnabled = true
        savePhotoButton.alpha = 1
        configureComments([])

        // Cancel image request.
        imageDataRequest?.cancel()
        
    }
}
