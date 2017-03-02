/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import SnapKit

private let cardHorizontalPadding = 16
private let cardBottomPadding: CGFloat = 24

private let cardSpacing = 18
private let cardProviderSpacing = 12

private let cardCoverPhotoHeight = 72

private let eventInsets = UIEdgeInsetsMake(10, 16, 10, 16)

// HACK: The amount of spacing needed to keep the event card the same height
// as the place card.
private let eventBottomSpacing = 67

class MapViewCardFooter: ExpandingCardView {

    private lazy var containerView: UIView = {
        let container = UIView()
        for view in [
            self.coverPhotoView,
            self.titleLabel,
            self.yelpProviderView,
            self.tripAdvisorProviderView,
            self.eventContainer,
            self.eventLabel,
            ] as [UIView] {
            container.addSubview(view)
        }
        return container
    }()

    private lazy var coverPhotoView: UIImageView = {
        let view = UIImageView()
        view.image = #imageLiteral(resourceName: "place-placeholder")
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Placeholder place"
        view.font = Fonts.mapViewFooterTitle
        return view
    }()

    private lazy var eventLabel: UILabel = {
        let view = UILabel()
        view.font = Fonts.mapViewFooterEvent
        view.textColor = UIColor.white
        return view
    }()

    private lazy var eventContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.detailsViewEventBackground
        return view
    }()

    fileprivate lazy var yelpProviderView =
        MapViewReviewProviderView(providerStarImageAccessor: YelpStarImageAccessor(),
                                  providerFromPlace: { place in return place.yelpProvider })
    fileprivate lazy var tripAdvisorProviderView =
        MapViewReviewProviderView(providerStarImageAccessor: TripAdvisorStarImageAccessor(),
                                  providerFromPlace: { place in return place.tripAdvisorProvider })

    private var eventConstraints = [Constraint]()
    private var placeConstraints = [Constraint]()

    init(bottomInset: CGFloat) {
        super.init()
        initStyle()
        contentView = containerView

        coverPhotoView.snp.makeConstraints { make in
            make.height.equalTo(cardCoverPhotoHeight)
            make.top.leading.trailing.equalToSuperview()
        }

        eventContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(coverPhotoView.snp.bottom)
        }

        eventLabel.snp.makeConstraints { make in
            make.edges.equalTo(eventContainer).inset(eventInsets)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)

            eventConstraints += [
                make.top.equalTo(eventContainer.snp.bottom).offset(cardSpacing).constraint,
                make.bottom.equalToSuperview().constraint.update(offset: -eventBottomSpacing),
            ]
            placeConstraints += [
                make.top.equalTo(coverPhotoView.snp.bottom).offset(cardSpacing).constraint,
                make.bottom.equalTo(yelpProviderView.snp.top).offset(-cardSpacing).constraint,
            ]
        }

        yelpProviderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)
            make.bottom.equalTo(tripAdvisorProviderView.snp.top).offset(-cardProviderSpacing)
        }

        tripAdvisorProviderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)
            make.bottom.equalToSuperview().offset(-cardBottomPadding - bottomInset)
        }

        eventConstraints.forEach { $0.deactivate() }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("coder not implemented") }

    private func initStyle() {
        cornerRadius = Style.cardViewCornerRadius

        layer.shadowOffset = Style.cardViewShadowOffset
        layer.shadowRadius = Style.cardViewShadowRadius
        layer.shadowOpacity = Style.cardViewShadowOpacity
    }

    func update(for place: Place) {
        if let url = place.photoURLs.first { // should never fail - we filter out places w/o photos.
            coverPhotoView.setImageWith(url)
        } else {
            coverPhotoView.image = #imageLiteral(resourceName: "cardview_image_loading")
        }
        titleLabel.text = place.name
        for provider in [yelpProviderView, tripAdvisorProviderView] as [MapViewReviewProviderView] {
            provider.update(for: place)
        }

        tripAdvisorProviderView.isHidden = place.isEvent
        yelpProviderView.isHidden = place.isEvent
        eventContainer.isHidden = !place.isEvent

        if place.isEvent {
            placeConstraints.forEach { $0.deactivate() }
            eventConstraints.forEach { $0.activate() }
        } else {
            eventConstraints.forEach { $0.deactivate() }
            placeConstraints.forEach { $0.activate() }
        }
        layoutIfNeeded()

        guard let (day, time) = place.hours?.getEventTimeText(forToday: Date()) else { return }
        eventLabel.text = String(format: Strings.mapView.eventHeader, day, time)
    }
}
