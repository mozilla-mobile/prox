/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import QuartzCore

enum ReviewContainerViewMode {
    case carouselView, detailsView
}

class ReviewContainerView: UIView {

    let verticalMargin: CGFloat
    let logoHeight: CGFloat
    let scoreHorizontalMargin: CGFloat

    var color: UIColor {
        didSet {
            self.reviewScore.color = color
        }
    }

    var score: Float = 0 {
        didSet {
            reviewScore.score = score
        }
    }

    lazy var reviewSiteLogo: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    lazy var reviewScore: ReviewScoreView = {
        let view = ReviewScoreView(color: self.color)
        return view
    }()

    lazy var numberOfReviewersLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()

    convenience init(color: UIColor, mode: ReviewContainerViewMode) {
        self.init(score: 0, color: color, mode: mode)
    }

    init(score: Float, color: UIColor, mode: ReviewContainerViewMode) {
        self.score = score
        self.color = color

        switch mode {
        case .carouselView:
            verticalMargin = 4
            logoHeight = 19
            scoreHorizontalMargin = 16

        case .detailsView:
            verticalMargin = 9
            logoHeight = 28
            scoreHorizontalMargin = 0
        }

        super.init(frame: .zero)
        setupSubviews()
        configure(byMode: mode) // must be called after super.init: references self.
    }

    private func configure(byMode mode: ReviewContainerViewMode) {
        switch mode {
        case .carouselView:
            numberOfReviewersLabel.font = Fonts.reviewsNumberOfReviewers
            numberOfReviewersLabel.textColor = Colors.reviewsNumberOfReviewers

        case.detailsView:
            numberOfReviewersLabel.font = Fonts.detailsViewReviewerText
            numberOfReviewersLabel.textColor = Colors.detailsViewCardSecondaryText
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(reviewSiteLogo)
        var constraints = [reviewSiteLogo.topAnchor.constraint(equalTo: self.topAnchor),
                           reviewSiteLogo.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                           reviewSiteLogo.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                           reviewSiteLogo.heightAnchor.constraint(equalToConstant: logoHeight)]
        addSubview(reviewScore)
        constraints.append(contentsOf: [reviewScore.topAnchor.constraint(equalTo: reviewSiteLogo.bottomAnchor, constant: verticalMargin),
                                        reviewScore.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: scoreHorizontalMargin),
                                        reviewScore.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -scoreHorizontalMargin),
                                        reviewScore.heightAnchor.constraint(equalToConstant: 4)])
        addSubview(numberOfReviewersLabel)
        constraints.append(contentsOf: [numberOfReviewersLabel.topAnchor.constraint(equalTo: reviewScore.bottomAnchor, constant: verticalMargin),
                                        numberOfReviewersLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                        numberOfReviewersLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                        numberOfReviewersLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)])
        // Note: setting a height on the label may affect margins but, by not including it,
        // the view will collapse if no review score is present

        constraints += [bottomAnchor.constraint(equalTo: numberOfReviewersLabel.bottomAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

}
