/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let viewHeight: CGFloat = 20

private let disabledAlpha: CGFloat = 0.4

class MapViewReviewProviderView: UIView {

    private let scoreView = UIImageView()
    private let reviewCountView = UILabel()

    private let providerStarImageAccessor: ProviderStarImageAccessor
    private let providerFromPlace: (Place) -> PlaceProvider?

    init(providerStarImageAccessor: ProviderStarImageAccessor, providerFromPlace: @escaping (Place) -> PlaceProvider?) {
        self.providerStarImageAccessor = providerStarImageAccessor
        self.providerFromPlace = providerFromPlace
        super.init(frame: .zero)

        initViews(withParent: self)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("coder not implemented") }

    // TODO: replace parent param with self in these methods: left in to save time during refactor.
    private func initViews(withParent parent: UIView) {
        scoreView.image = providerStarImageAccessor.image(forScore: 5)
        scoreView.alpha = disabledAlpha
        scoreView.clipsToBounds = true
        scoreView.contentMode = .scaleAspectFit

        reviewCountView.text = Strings.mapView.noInfo
        reviewCountView.font = Fonts.mapViewFooterReviewCount
        reviewCountView.textColor = Colors.mapViewFooterReviewCount

        layoutViews(withParent: parent)
    }

    private func layoutViews(withParent parent: UIView) {
        for view in [scoreView, reviewCountView] as [UIView] {
            parent.addSubview(view)
        }

        parent.snp.makeConstraints { make in
            make.height.equalTo(viewHeight)
        }

        providerStarImageAccessor.widthConstraint(for: scoreView, withViewHeight: viewHeight).isActive = true
        scoreView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
        }

        reviewCountView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
        }
    }

    func update(for place: Place) {
        guard let provider = providerFromPlace(place),
                let rating = provider.rating,
                provider.totalReviewCount > 0 else {
            scoreView.alpha = disabledAlpha
            scoreView.image = providerStarImageAccessor.image(forScore: 0)
            reviewCountView.text = Strings.mapView.noInfo
            return
        }

        let reviewCount = provider.totalReviewCount
        scoreView.alpha = 1
        scoreView.image = providerStarImageAccessor.image(forScore: rating)
        reviewCountView.text = String(format: Strings.mapView.numReviews, reviewCount, (reviewCount == 1) ? "" : "s")
    }
}
