/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let yelpAssetSize = CGSize(width: 132, height: 24)
private let viewHeight: CGFloat = 20

// HACK: when we scale inside a UIImageView, the UIImageView keeps the size the of the original image
// (rather than taking the scaled image size) so we have to set the size ourselves. For speed, we
// hardcode yelp for now. A proper alternative would be to scale the image outside the image view
// and set the image view with the scaled image.
private let scoreViewWidth = (viewHeight / yelpAssetSize.height) * yelpAssetSize.width

class MapViewReviewProvider: UIView {

    var score: Float = 0 {
        didSet { /* todo: update image */ }
    }

    var reviewCount: Int = 0 {
        didSet { /* todo: update review count */ }
    }

    private lazy var scoreView: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        view.image = #imageLiteral(resourceName: "score_yelp_5")
        return view
    }()

    private lazy var reviewCountView: UILabel = {
        let view = UILabel()
        view.text = "10 reviews"
        view.font = Fonts.mapViewFooterReviewCount
        view.textColor = Colors.mapViewFooterReviewCount
        return view
    }()

    init() {
        super.init(frame: .zero)
        for view in [scoreView, reviewCountView] as [UIView] {
            addSubview(view)
        }

        snp.makeConstraints { make in
            make.height.equalTo(viewHeight)
        }

        scoreView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.width.equalTo(scoreViewWidth)
        }

        reviewCountView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
        }
    }

    required init(coder: NSCoder) {
        fatalError("coder not implemented")
    }
}
