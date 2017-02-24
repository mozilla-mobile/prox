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

class MapViewCardFooter: ExpandingCardView {

    private lazy var containerView: UIView = {
        let container = UIView()
        for view in [
            self.coverPhotoView,
            self.titleLabel,
            self.yelpProviderView,
            self.tripAdvisorProviderView,
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

    fileprivate lazy var yelpProviderView = MapViewYelpReviewProviderView()
    fileprivate lazy var tripAdvisorProviderView = MapViewTripAdvisorReviewProviderView()

    init(bottomInset: CGFloat) {
        super.init()
        initStyle()
        contentView = containerView

        coverPhotoView.snp.makeConstraints { make in
            make.height.equalTo(cardCoverPhotoHeight)
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(titleLabel.snp.top).offset(-cardSpacing)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)
            make.bottom.equalTo(yelpProviderView.snp.top).offset(-cardSpacing)
        }

        yelpProviderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)
            make.bottom.equalTo(tripAdvisorProviderView.snp.top).offset(-cardProviderSpacing)
        }

        tripAdvisorProviderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardHorizontalPadding)
            make.bottom.equalToSuperview().offset(-cardBottomPadding - bottomInset)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("coder not implemented") }

    private func initStyle() {
        cornerRadius = Style.cardViewCornerRadius

        shadowOffset = Style.cardViewShadowOffset
        shadowRadius = Style.cardViewShadowRadius
        shadowOpacity = Style.cardViewShadowOpacity
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
    }
}
