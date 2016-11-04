/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import QuartzCore

class PlaceCarouselCollectionViewCell: UICollectionViewCell {

    lazy var roundedBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewPlaceCardBackground
        view.layer.cornerRadius = 5
        view.clipsToBounds = true
        view.accessibilityIdentifier = "Background"
        return view
    }()

    lazy var shadowView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewPlaceCardBackground
        view.layer.cornerRadius = 5

        view.layer.shadowColor = UIColor.darkGray.cgColor
        view.layer.shouldRasterize = true
        view.accessibilityIdentifier = "Shadow"

        return view
    }()

    lazy var placeImage: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.accessibilityIdentifier = "Image"

        let opacityView = UIView()
        opacityView.backgroundColor = Colors.carouselViewImageOpacityLayer
        opacityView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(opacityView)

        opacityView.topAnchor.constraint(equalTo: imageView.topAnchor).isActive = true
        opacityView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor).isActive = true
        opacityView.heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        opacityView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor).isActive = true
        opacityView.accessibilityIdentifier = "ImageOpacityLayer"


        return imageView
    }()

    lazy var yelpReview: ReviewContainerView = {
        let view = ReviewContainerView(color: Colors.yelp, mode: .carouselView)
        view.accessibilityIdentifier = "YelpReview"

        return view
    }()

    lazy var tripAdvisorReview: ReviewContainerView = {
        let view = ReviewContainerView(color: Colors.tripAdvisor, mode: .carouselView)
        view.accessibilityIdentifier = "TripAdvisorReview"
        return view
    }()

    lazy var category: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewPlaceCardImageText
        label.font = Fonts.carouselViewPlaceCardCategory
        label.accessibilityIdentifier = "CategoryLabel"
        return label
    }()

    lazy var name: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewPlaceCardImageText
        label.font = Fonts.carouselViewPlaceCardName
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.accessibilityIdentifier = "NameLabel"
        return label
    }()

    lazy var locationImage: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = Colors.carouselViewPlaceCardImageText
        imageView.accessibilityIdentifier = "LocationImage"
        return imageView
    }()

    lazy var location: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewPlaceCardImageText
        label.font = Fonts.carouselViewPlaceCardLocation
        label.accessibilityIdentifier = "LocationLabel"
        return label
    }()

    private var locationLabelLeadingConstraint: NSLayoutConstraint?
    private var locationImageHeightConstraint: NSLayoutConstraint?
    private var locationImageWidthConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }



    override var isSelected: Bool {
        didSet {
            if isSelected {
                shadowView.layer.shadowOffset = CGSize(width: 2, height: 2)
                shadowView.layer.shadowOpacity = 0.5
                shadowView.layer.shadowRadius = 2
            } else {
                shadowView.layer.shadowOffset = CGSize(width: 1, height: 1)
                shadowView.layer.shadowOpacity = 0.25
                shadowView.layer.shadowRadius = 1
            }
        }
    }
    
    private func setupViews() {
        contentView.addSubview(roundedBackgroundView)

        var constraints = [roundedBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
                           roundedBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                           roundedBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)]

        contentView.insertSubview(shadowView, belowSubview: roundedBackgroundView)
        constraints.append(contentsOf: [shadowView.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor),
                                        shadowView.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor),
                                        shadowView.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor),
                                        shadowView.bottomAnchor.constraint(lessThanOrEqualTo: roundedBackgroundView.bottomAnchor),
                                        shadowView.heightAnchor.constraint(equalTo: roundedBackgroundView.heightAnchor),
                                        shadowView.widthAnchor.constraint(equalTo: roundedBackgroundView.widthAnchor)])

        roundedBackgroundView.addSubview(placeImage)
        constraints.append(contentsOf: [placeImage.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor),
                                        placeImage.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor),
                                        placeImage.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor),
                                        placeImage.heightAnchor.constraint(equalToConstant: 201)])


        placeImage.addSubview(category)
        constraints.append(contentsOf: [category.leadingAnchor.constraint(equalTo: name.leadingAnchor),
                                        category.trailingAnchor.constraint(equalTo: name.trailingAnchor),
                                        category.bottomAnchor.constraint(equalTo: name.topAnchor, constant: -9)])

        let lineView = HorizontalLineView()
        lineView.backgroundColor = .clear
        lineView.color = Colors.carouselViewPlaceCardImageText
        lineView.startX = 0.0
        placeImage.addSubview(lineView)
        constraints.append(contentsOf: [lineView.leadingAnchor.constraint(equalTo: category.leadingAnchor, constant: 9),
                                        lineView.topAnchor.constraint(equalTo: category.bottomAnchor, constant: 2),
                                        lineView.widthAnchor.constraint(equalToConstant: 12.0),
                                        lineView.heightAnchor.constraint(equalToConstant: 2.0)])

        placeImage.addSubview(name)
        constraints.append(contentsOf: [name.leadingAnchor.constraint(equalTo: placeImage.leadingAnchor, constant: 12.0),
                                         name.bottomAnchor.constraint(equalTo: location.topAnchor),
                                         name.trailingAnchor.constraint(equalTo: placeImage.trailingAnchor)])

        placeImage.addSubview(locationImage)
        constraints.append(contentsOf: [locationImage.leadingAnchor.constraint(equalTo: placeImage.leadingAnchor, constant: 13.0),
                                        locationImage.bottomAnchor.constraint(equalTo: placeImage.bottomAnchor, constant: -16)])
        placeImage.addSubview(location)
        constraints.append(contentsOf: [location.bottomAnchor.constraint(equalTo: placeImage.bottomAnchor, constant: -12),
                                        location.trailingAnchor.constraint(equalTo: placeImage.trailingAnchor, constant: -12)])

        roundedBackgroundView.addSubview(yelpReview)
        constraints.append(contentsOf: [yelpReview.topAnchor.constraint(equalTo: placeImage.bottomAnchor, constant: 13),
                                        yelpReview.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor),
                                        yelpReview.heightAnchor.constraint(equalToConstant: 50),
                                        yelpReview.widthAnchor.constraint(equalToConstant: 100)])

        roundedBackgroundView.addSubview(tripAdvisorReview)
        constraints.append(contentsOf: [tripAdvisorReview.topAnchor.constraint(equalTo: placeImage.bottomAnchor, constant: 13),
                                        tripAdvisorReview.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor),
                                        tripAdvisorReview.heightAnchor.constraint(equalToConstant: 50),
                                        tripAdvisorReview.widthAnchor.constraint(equalToConstant: 100)])

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var updatedConstraints = [roundedBackgroundView.heightAnchor.constraint(equalToConstant: contentView.frame.size.height - 2),
                                  roundedBackgroundView.widthAnchor.constraint(equalToConstant: contentView.frame.size.width)]

        var deactivateConstraints = [NSLayoutConstraint]()
        if let _ = locationImage.image {
            if let locationLeading = locationLabelLeadingConstraint {
                deactivateConstraints.append(locationLeading)
            }
            locationLabelLeadingConstraint = location.leadingAnchor.constraint(equalTo: locationImage.trailingAnchor, constant: 4.0)
            if let locationImageHeight = locationImageHeightConstraint,
                let locationImageWidth = locationImageWidthConstraint {
                deactivateConstraints.append(contentsOf: [locationImageHeight, locationImageWidth])
            }
            locationImageHeightConstraint = locationImage.heightAnchor.constraint(lessThanOrEqualToConstant: 10.0)
            locationImageWidthConstraint = locationImage.widthAnchor.constraint(lessThanOrEqualToConstant: 7.0)

            updatedConstraints.append(contentsOf: [locationLabelLeadingConstraint!, locationImageWidthConstraint!, locationImageHeightConstraint!])
        } else {
            if let locationLeading = locationLabelLeadingConstraint {
                deactivateConstraints.append(locationLeading)
            }
            locationLabelLeadingConstraint = location.leadingAnchor.constraint(equalTo: placeImage.leadingAnchor, constant: 12.0)
            if let locationImageHeight = locationImageHeightConstraint,
                let locationImageWidth = locationImageWidthConstraint {
                deactivateConstraints.append(contentsOf: [locationImageHeight, locationImageWidth])
            }
            locationImageHeightConstraint = nil
            locationImageWidthConstraint = nil

            updatedConstraints.append(contentsOf: [locationLabelLeadingConstraint!])
        }

        NSLayoutConstraint.deactivate(deactivateConstraints)
        NSLayoutConstraint.activate(updatedConstraints)
    }
    
}
