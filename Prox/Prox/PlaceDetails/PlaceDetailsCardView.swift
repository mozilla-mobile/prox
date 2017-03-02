/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol PlaceDetailsCardDelegate: class {
    func placeDetailsCardView(cardView: PlaceDetailsCardView, heightDidChange newHeight: CGFloat)
}

class PlaceDetailsCardView: UIView {

    weak var delegate: PlaceDetailsCardDelegate?

    let margin: CGFloat = 24
    let CardMarginBottom: CGFloat = 20 // TODO: name

    // Contains the content: the outer view is used to display a shadow.
    // This is necessary because the eventView drew its background color over the round corners.
    // I tried a solution that added also rounded the top corners to the eventView, but there was a
    // visual artifact where the card's white background shown through the corners.
    lazy var contentView = UIView()

    lazy var containingStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews:[self.labelContainer,
                                                 self.iconInfoViewContainer,
                                                 self.reviewViewContainer,
                                                 self.eventDescriptionView,
                                                 self.wikiDescriptionView,
                                                 self.tripAdvisorDescriptionView,
                                                 self.yelpDescriptionView
            ])
        view.axis = .vertical
        view.spacing = self.margin

        view.layoutMargins = UIEdgeInsets(top: self.margin, left: 0,
                                          bottom: self.CardMarginBottom, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    func setContainingStackViewMargins(isTopMarginPresent: Bool) {
        // Margins initialized in lazy init.
        containingStackView.layoutMargins = UIEdgeInsets(top: isTopMarginPresent ? self.margin : 0, left: 0,
                                                         bottom: self.CardMarginBottom, right: 0)
    }

    // MARK: Outer views.
    // TODO: accessibility labels (and parent view)
    // TODO: set line height on all text. http://stackoverflow.com/a/5513730
    lazy var labelContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.titleLabel,
                                                  self.categoryLabel,
                                                  self.urlLabel])
        view.axis = .vertical
        view.spacing = 4

        view.layoutMargins = UIEdgeInsets(top: 0, left: self.margin, bottom: 0, right: self.margin)
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
    lazy var reviewViewContainer: UIStackView = {
        let reviewStackView = UIStackView(arrangedSubviews: [self.yelpReviewView,
                                          self.tripAdvisorReviewView])
        reviewStackView.layoutMargins = UIEdgeInsets(top: 0, left: self.margin, bottom: 0, right: self.margin)
        reviewStackView.spacing = 25
        reviewStackView.axis = .horizontal
        reviewStackView.isLayoutMarginsRelativeArrangement = true
        reviewStackView.distribution = .fillEqually
        return reviewStackView
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

    lazy var urlLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardLinkText
        view.font = Fonts.detailsViewCategoryText
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var travelTimeView = PlaceDetailsTravelTimesView()

    lazy var hoursView: PlaceDetailsIconInfoView = {
        let view = PlaceDetailsIconInfoView(enableForwardArrow: false)
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
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var tripAdvisorDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "Highlights from TripAdvisor",
                                               icon: UIImage(named: "logo_TA_small"),
                                               type: DetailType.tripadvisor,
                                               expanded: false)

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on TripAdvisor", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    }()

    lazy var wikiDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "The top line from Wikipedia",
                                        icon: UIImage(named: "logo_wikipedia"),
                                        type: DetailType.wikipedia,
                                        expanded: false)

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on Wikipedia", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    }()

    lazy var yelpDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "The latest from Yelp",
                                                               icon: UIImage(named: "logo_yelp_small"),
                                                               type: DetailType.yelp,
                                                               expanded: false)
        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: "Read more on Yelp", attributes: underlineAttribute)
        view.readMoreLink.attributedText = underlineAttributedString
        return view
    } ()

    lazy var eventDescriptionView: PlaceDetailsDescriptionView = {
        let view = PlaceDetailsDescriptionView(labelText: "Event details",
                                               icon: nil,
                                               type: DetailType.event,
                                               expanded: false)
        return view
    } ()

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
        layer.shadowOffset = Style.cardViewShadowOffset
        layer.shadowRadius = Style.cardViewShadowRadius
        layer.shadowOpacity = Style.cardViewShadowOpacity
    }

    private func setupViews() {
        backgroundColor = Colors.detailsViewCardBackground // cannot be transparent to display shadow
        contentView.backgroundColor = Colors.detailsViewCardBackground

        layer.cornerRadius = Style.cardViewCornerRadius
        contentView.layer.cornerRadius = Style.cardViewCornerRadius
        contentView.layer.masksToBounds = true

        addSubview(contentView)
        var constraints = [contentView.topAnchor.constraint(equalTo: topAnchor),
                           contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                           contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                           contentView.bottomAnchor.constraint(equalTo: bottomAnchor)]

        // Note: The constraints of subviews broke when I used leading/trailing, rather than
        // centerX & width. The parent constraints are set with centerX & width - related?
        contentView.addSubview(containingStackView)
        constraints += [containingStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                        containingStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                        containingStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                        containingStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)

        setupGestureRecognizers()

    }


    private func setupGestureRecognizers() {
        tripAdvisorDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap(gestureRecognizer:))))
        wikiDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap(gestureRecognizer:))))
        yelpDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap(gestureRecognizer:))))
        eventDescriptionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap(gestureRecognizer:))))
    }

    @objc private func didTap(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended,
            let descriptionView = gestureRecognizer.view as? PlaceDetailsDescriptionView else {
                return
        }

        descriptionView.didTap()
        self.layoutIfNeeded()

    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateViewSize()
    }

    // TODO: when else can we call this? layoutSubviews is called when we scroll and we don't want to calculate all this each time...
    private func updateViewSize() {
        delegate?.placeDetailsCardView(cardView: self, heightDidChange: bounds.height)
    }

    func updateUI(forPlace place: Place) {
        // Labels will gracefully collapse on nil.
        titleLabel.text = place.name
        categoryLabel.text = PlaceUtilities.getString(forCategories: place.categories.names)
        updateURLText(place.website)

        updateHoursUI(place.hours)

        let viewDescriptions: [(view: PlaceDetailsDescriptionView, description: String?)] = [
            (eventDescriptionView, place.customProvider?.description),
            (wikiDescriptionView, place.wikipediaProvider?.description),
            (tripAdvisorDescriptionView, place.tripAdvisorProvider?.description),
            (yelpDescriptionView, place.yelpProvider.description),
        ]

        var didExpand = false
        for viewDescription in viewDescriptions {
            updateDescriptionViewUI(forText: viewDescription.description, onView: viewDescription.view, expanded: !didExpand)
            didExpand = didExpand || viewDescription.description != nil
        }

        PlaceUtilities.updateReviewUI(fromProvider: place.yelpProvider, onView: yelpReviewView)
        PlaceUtilities.updateReviewUI(fromProvider: place.tripAdvisorProvider, onView: tripAdvisorReviewView)
    }

    private func updateURLText(_ url: URL?) {
        guard let url = url?.absoluteString else {
            urlLabel.text = nil
            return
        }

        let underlineAttribute = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let underlineAttributedString = NSAttributedString(string: url, attributes: underlineAttribute)
        urlLabel.attributedText = underlineAttributedString
    }

    private func updateHoursUI(_ hours: OpenHours?) {
        guard let (primaryText, secondaryText) = getStringsForOpenHours(hours, forDate: Date()) else {
            hoursView.iconView.isHidden = true
            hoursView.isPrimaryTextLabelHidden = true
            hoursView.secondaryTextLabel.text = "Check listing\nfor hours"
            hoursView.secondaryTextLabel.numberOfLines = 2
            return
        }

        hoursView.iconView.isHidden = false
        hoursView.isPrimaryTextLabelHidden = false
        hoursView.primaryTextLabel.text = primaryText
        hoursView.secondaryTextLabel.text = secondaryText
        hoursView.secondaryTextLabel.numberOfLines = 1
    }

    private func updateDescriptionViewUI(forText text: String?, onView view: PlaceDetailsDescriptionView, expanded: Bool) {
        view.isHidden = text == nil ? true : false
        view.descriptionLabel.text = text
        view.setExpandableView(isExpanded: expanded)
    }

    private func getStringsForOpenHours(_ openHours: OpenHours?, forDate date: Date) -> (primary: String, secondary: String)? {
        guard let openHours = openHours else {
            // if hours is nil, we assume this place has no listed hours (e.g. beach).
            return nil
        }

        let now = Date()
        if openHours.isOpen(atTime: now),
            let closingTime = openHours.closingTime(forTime: now) {
            return ("Open", "Until \(closingTime)")
        } else if let openingTime = openHours.nextOpeningTime(forTime: now) {
            return ("Closed", "Until \(openingTime)")
        }

        return nil
    }
}
