/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

// TODO: make this scroll!
class PlaceDetailsCardView: UIView {

    // TODO: accessibility labels (and parent view)
    // TODO: set line height on all text. http://stackoverflow.com/a/5513730
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardPrimaryText
        view.font = Fonts.detailsViewTitleText
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        return view
    }()

    lazy var categoryLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardPrimaryText
        view.font = Fonts.detailsViewCategoryText
        return view
    }()

    // TODO: Set styling.
    lazy var urlLabel: UILabel = {
        let view = UILabel()
        view.textColor = .blue
        view.font = Fonts.detailsViewCategoryText // TODO
        return view
    }()

    lazy var travelTimeView: PlaceDetailsIconInfoView = {
        let view = PlaceDetailsIconInfoView() // TODO: icon depending on walking/driving
        return view
    }()

    lazy var hoursView: PlaceDetailsIconInfoView = {
        let view = PlaceDetailsIconInfoView()
        view.iconView.image = UIImage(named: "icon_times")
        return view
    }()

    lazy var yelpReviewView: ReviewContainerView = {
        let view = ReviewContainerView(color: Colors.yelp, mode: .detailsView)
        view.reviewSiteLogo.image = UIImage(named: "logo_yelp")
        return view
    }()

    lazy var tripAdvisorReviewView: ReviewContainerView = {
        let view = ReviewContainerView(color: Colors.tripAdvisor, mode: .detailsView)
        view.reviewSiteLogo.image = UIImage(named: "logo_ta")
        return view
    }()

    lazy var wikiDescriptionView = PlaceDetailsDescriptionView(labelText: "Wikipedia summary",
                                                               icon: nil,
                                                               horizontalMargin: 16)

    lazy var yelpDescriptionView = PlaceDetailsDescriptionView(labelText: "Yelp top review",
                                                               icon: nil,
                                                               horizontalMargin: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupShadow()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupShadow() {
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.4
    }

    private func setupViews() {
        setTestData() // TODO: rm
        backgroundColor = Colors.detailsViewCardBackground
        layer.cornerRadius = 10
        clipsToBounds = true

        addSubview(titleLabel)
        var constraints = [titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
                           titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
                           titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)]

        addSubview(categoryLabel)
        constraints += [categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                        categoryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                        categoryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)]

        addSubview(urlLabel)
        constraints += [urlLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 4),
                        urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                        urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)]

        addSubview(travelTimeView)
        constraints += [travelTimeView.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 24),
                        travelTimeView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                        travelTimeView.trailingAnchor.constraint(equalTo: centerXAnchor),
                        travelTimeView.heightAnchor.constraint(equalToConstant: 48)]

        addSubview(hoursView)
        constraints += [hoursView.topAnchor.constraint(equalTo: travelTimeView.topAnchor),
                        hoursView.leadingAnchor.constraint(equalTo: centerXAnchor),
                        hoursView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                        hoursView.bottomAnchor.constraint(equalTo: travelTimeView.bottomAnchor)]

        addSubview(yelpReviewView)
        constraints += [yelpReviewView.topAnchor.constraint(equalTo: travelTimeView.bottomAnchor, constant: 24),
                        yelpReviewView.centerXAnchor.constraint(equalTo: travelTimeView.centerXAnchor),
                        yelpReviewView.widthAnchor.constraint(equalToConstant: 128),
                        yelpReviewView.bottomAnchor.constraint(equalTo: yelpReviewView.numberOfReviewersLabel.bottomAnchor)]
        // TODO: heightAnchor. I'd like to leave out the constraint and use the intrinsic content height.
        // However, if I leave it out, the bottom anchor is too high and cuts off the subviews.
        // Using the subview bottom anchor is really bad. :(

        addSubview(tripAdvisorReviewView)
        constraints += [tripAdvisorReviewView.topAnchor.constraint(equalTo: travelTimeView.bottomAnchor, constant: 24),
                        tripAdvisorReviewView.centerXAnchor.constraint(equalTo: hoursView.centerXAnchor),
                        tripAdvisorReviewView.widthAnchor.constraint(equalTo: yelpReviewView.widthAnchor),
                        tripAdvisorReviewView.bottomAnchor.constraint(equalTo: yelpReviewView.bottomAnchor)]

        addSubview(wikiDescriptionView)
        constraints += [wikiDescriptionView.topAnchor.constraint(equalTo: yelpReviewView.bottomAnchor, constant: 24),
                        wikiDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor),
                        wikiDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor),
                        wikiDescriptionView.heightAnchor.constraint(equalToConstant: 56)]

        addSubview(yelpDescriptionView)
        constraints += [yelpDescriptionView.topAnchor.constraint(equalTo: wikiDescriptionView.bottomAnchor),
                        yelpDescriptionView.leadingAnchor.constraint(equalTo: wikiDescriptionView.leadingAnchor),
                        yelpDescriptionView.trailingAnchor.constraint(equalTo: wikiDescriptionView.trailingAnchor),
                        yelpDescriptionView.heightAnchor.constraint(equalTo: wikiDescriptionView.heightAnchor)]

        // TODO: have to be flexible to rm bottom views if data not available
        constraints += [bottomAnchor.constraint(equalTo: yelpDescriptionView.bottomAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func setTestData() {
        titleLabel.text = "The Location Title"
        categoryLabel.text = ["Hotel", "Bar", "Pool"].joined(separator: " • ") // TODO: dot is too thick
        urlLabel.text = "http://mozilla.org"
        travelTimeView.primaryTextLabel.text = "18 min"
        travelTimeView.secondaryTextLabel.text = "Walking"
        travelTimeView.iconView.image = UIImage(named: "icon_walkingdist")
        hoursView.primaryTextLabel.text = "10:00 pm"
        hoursView.secondaryTextLabel.text = "Closing time"
        yelpReviewView.score = 3
        yelpReviewView.numberOfReviewersLabel.text = "567 Reviews"
        tripAdvisorReviewView.score = 3
        tripAdvisorReviewView.numberOfReviewersLabel.text = "123 reviews"
    }
}
