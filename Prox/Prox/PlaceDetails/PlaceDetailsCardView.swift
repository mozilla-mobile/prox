/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceDetailsCardView: UIScrollView {

    let TopMargin: CGFloat = 24
    let CardMarginBottom: CGFloat = 24 // TODO: name

    lazy var containingStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.labelContainer,
                                                  self.iconInfoViewContainer,
                                                  self.reviewViewContainer,
                                                  self.descriptionViewContainer])
        view.axis = .vertical
        view.spacing = 24

        view.layoutMargins = UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    // MARK: Outer views.
    // TODO: accessibility labels (and parent view)
    // TODO: set line height on all text. http://stackoverflow.com/a/5513730
    lazy var labelContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.titleLabel,
                                                  self.categoryLabel,
                                                  self.urlLabel])
        view.axis = .vertical
        view.spacing = 4

        view.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    lazy var iconInfoViewContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.travelTimeView,
                                                  self.hoursView])
        view.axis = .horizontal
        view.distribution = .fillEqually

        view.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    // Ideally we also use a UIStackView but the review dots stretched too
    // far across the screen and it was faster to do it this way.
    lazy var reviewViewContainer = UIView()

    // Prevents spacing between views from parent stack view.
    lazy var descriptionViewContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.wikiDescriptionView,
                                                  self.yelpDescriptionView])
        view.axis = .vertical
        return view
    }()

    // MARK: Inner views
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
                                                               icon: UIImage(named: "logo_wikipedia"),
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

    // TODO: can't set shadow on scroll view to allow masking contents.
    private func setupShadow() {
        layer.masksToBounds = true
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.4
    }

    private func setupViews() {
        setTestData() // TODO: rm
        backgroundColor = Colors.detailsViewCardBackground
        layer.cornerRadius = 10

        // Note: The constraints of subviews broke when I used leading/trailing, rather than
        // centerX & width. The parent constraints are set with centerX & width - related?
        addSubview(containingStackView)
        var constraints = [containingStackView.topAnchor.constraint(equalTo: topAnchor),
                           containingStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           containingStackView.widthAnchor.constraint(equalTo: widthAnchor),
                           containingStackView.bottomAnchor.constraint(equalTo: bottomAnchor)]

        // Already added to stack view.
        constraints += [reviewViewContainer.bottomAnchor.constraint(equalTo: yelpReviewView.bottomAnchor)]

        reviewViewContainer.addSubview(yelpReviewView)
        constraints += [yelpReviewView.topAnchor.constraint(equalTo: reviewViewContainer.topAnchor),
                        yelpReviewView.centerXAnchor.constraint(equalTo: travelTimeView.centerXAnchor),
                        yelpReviewView.widthAnchor.constraint(equalToConstant: 128)]

        reviewViewContainer.addSubview(tripAdvisorReviewView)
        constraints += [tripAdvisorReviewView.topAnchor.constraint(equalTo: yelpReviewView.topAnchor),
                        tripAdvisorReviewView.centerXAnchor.constraint(equalTo: hoursView.centerXAnchor),
                        tripAdvisorReviewView.widthAnchor.constraint(equalTo: yelpReviewView.widthAnchor)]

       constraints += [wikiDescriptionView.heightAnchor.constraint(equalToConstant: 56),
                       yelpDescriptionView.heightAnchor.constraint(equalTo: wikiDescriptionView.heightAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewSize()
    }

    // TODO: when else can we call this? layoutSubviews is called when we scroll and we don't want to calculate all this each time...
    private func updateViewSize() {
        let widthFromConstraints = bounds.width

        let contentHeight = containingStackView.bounds.height
        let newContentSize = CGSize(width: widthFromConstraints, height: contentHeight)

        let cardMinY = frame.minY
        let cardMaxY = (window?.frame.maxY)! - CardMarginBottom
        let cardHeight = min(contentHeight, cardMaxY - cardMinY) // grow with content until margin
        let newFrame = CGRect(origin: frame.origin, size: CGSize(width: widthFromConstraints, height: cardHeight))

        // Re-setting the frame on every layoutSubview cancels bounce, via http://stackoverflow.com/a/3231675
        if contentSize != newContentSize { contentSize = newContentSize }
        if frame != newFrame { frame = newFrame }
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
