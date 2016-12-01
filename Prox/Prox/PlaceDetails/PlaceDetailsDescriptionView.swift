/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

fileprivate enum UIMode {
    case collapsed, expanded
}

enum DetailType {
    case wikipedia, yelp, tripadvisor
}

class PlaceDetailsDescriptionView: UIView {

    private let toggleEventType: String

    private let horizontalMargin: CGFloat = 16.0
    private let expandableViewContentLeftMargin: CGFloat = 8 // aligned with card view title.

    fileprivate var uiMode: UIMode

    lazy var logoView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var label: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionTitle
        return view
    }()

    // TODO: icon
    lazy var expandButton: ChevronView = {
        let view = ChevronView(direction: self.uiMode == .collapsed ? .down : .up)
        view.style = .angular
        view.tintColor = Colors.detailsViewDescriptionExpandArrow
        view.lineWidth = 1.0
        return view
    }()

    lazy var descriptionLabel: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionText
        view.textColor = Colors.detailsViewCardSecondaryText
        view.numberOfLines = 0
        return view
    }()

    lazy var descriptionTitleView: HorizontalLineView = {
        let view = HorizontalLineView()
        view.backgroundColor = .clear
        view.color = Colors.detailsViewCardSeparator
        view.startX = 0.0
        view.startY = 0.0
        view.endY = 0.0
        return view
    }()

    lazy var expandableView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [self.descriptionLabel, self.readMoreLink])
        view.axis = .vertical
        view.spacing = 10
        view.distribution = .equalSpacing
        view.layoutMargins = UIEdgeInsets(top: 0, left: self.expandableViewContentLeftMargin,
                                          bottom: 0, right: self.horizontalMargin)
        view.isLayoutMarginsRelativeArrangement = true

        return view
    }()

    lazy var readMoreLink: UILabel = {
        let label = UILabel()
        label.textColor = Colors.detailsViewCardLinkText
        label.font = Fonts.detailsViewCategoryText

        label.isUserInteractionEnabled = true
        return label
    }()

    lazy var descriptionTitleViewBottomToParentBottomConstraint: NSLayoutConstraint = {
        return self.descriptionTitleView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
    }()

    lazy var expandableViewBottomConstraint: NSLayoutConstraint = {
        let constraint = self.expandableView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: self.uiMode == .collapsed ? 0 : -10)
        constraint.priority = 999
        return constraint
    }()

    lazy var logoBottomConstraint: NSLayoutConstraint = {
        let constraint = self.logoView.bottomAnchor.constraint(equalTo: self.descriptionTitleView.bottomAnchor, constant: self.uiMode == .collapsed ? 0 : -20)
        constraint.priority = 999
        return constraint
    }()

    init(labelText: String,
         icon: UIImage?,
         type: DetailType,
         expanded: Bool = true) {
        switch type {
        case .yelp:
            toggleEventType = AnalyticsEvent.YELP_TOGGLE
        case .wikipedia:
            toggleEventType = AnalyticsEvent.WIKIPEDIA_TOGGLE
        case .tripadvisor:
            toggleEventType = AnalyticsEvent.TRIPADVISOR_TOGGLE
        }
        uiMode = expanded ? .expanded : .collapsed
        super.init(frame: .zero)

        logoView.image = icon
        label.text = labelText
        backgroundColor = .clear

        setupSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(descriptionTitleView)
        var constraints = [descriptionTitleView.topAnchor.constraint(equalTo: topAnchor),
                           descriptionTitleView.leadingAnchor.constraint(equalTo: leadingAnchor),
                           descriptionTitleView.trailingAnchor.constraint(equalTo: trailingAnchor)]

        descriptionTitleView.addSubview(logoView)
        constraints += [logoView.centerXAnchor.constraint(equalTo: descriptionTitleView.leadingAnchor, constant: 24),
                        logoView.heightAnchor.constraint(equalToConstant: 16),
                        logoView.topAnchor.constraint(equalTo: descriptionTitleView.topAnchor, constant: 20),
                        logoBottomConstraint]

        descriptionTitleView.addSubview(label)
        constraints += [label.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
                        label.leadingAnchor.constraint(equalTo: descriptionTitleView.leadingAnchor, constant: 48),
                        label.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -horizontalMargin)]

        descriptionTitleView.addSubview(expandButton)
        constraints += [expandButton.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
                        expandButton.trailingAnchor.constraint(equalTo: descriptionTitleView.trailingAnchor, constant: -horizontalMargin),
                        expandButton.widthAnchor.constraint(equalToConstant: 16),
                        expandButton.heightAnchor.constraint(equalToConstant: 16)]

        addSubview(expandableView)
        constraints += [expandableView.topAnchor.constraint(equalTo: descriptionTitleView.bottomAnchor),
                        expandableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalMargin),
                        expandableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalMargin),
                        expandableViewBottomConstraint]

        if uiMode == .collapsed {
            constraints += [descriptionTitleViewBottomToParentBottomConstraint]
        }

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    func didTap() {
        let action = uiMode == .collapsed ? "expand" : "collapse"
        Analytics.logEvent(event: toggleEventType, params: [AnalyticsEvent.PARAM_ACTION: action])
        setExpandableView(isExpanded: uiMode == .collapsed)
    }

    func setExpandableView(isExpanded shouldExpand: Bool) {
        if shouldExpand {
            uiMode = .expanded
            expandableViewBottomConstraint.constant = -10
            logoBottomConstraint.constant = -20
            expandButton.direction = .up

            expandableView.isHidden = false
            descriptionTitleViewBottomToParentBottomConstraint.isActive = false
        } else {
            uiMode = .collapsed
            expandableViewBottomConstraint.constant = 0
            logoBottomConstraint.constant = 0
            expandButton.direction = .down

            descriptionTitleViewBottomToParentBottomConstraint.isActive = true
            expandableView.isHidden = true
        }

        setNeedsLayout()
    }
}
