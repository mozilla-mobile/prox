/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import QuartzCore

class ReviewContainerView: UIView {

    var color: UIColor? {
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
        let view = ReviewScoreView()
        view.color = self.color
        return view
    }()

    lazy var numberOfReviewersLabel: UILabel = {
        let label = UILabel()
        label.font = Fonts.reviewsNumberOfReviewers
        label.textColor = Colors.reviewsNumberOfReviewers
        label.textAlignment = .center
        return label
    }()

    convenience init() {
        self.init(score: 0)
    }

    init(score: Float) {
        super.init(frame: .zero)
        self.score = score
        setupSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(reviewSiteLogo)
        var constraints = [reviewSiteLogo.topAnchor.constraint(equalTo: self.topAnchor),
                           reviewSiteLogo.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                           reviewSiteLogo.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                           reviewSiteLogo.heightAnchor.constraint(equalToConstant: 19.0)]
        addSubview(reviewScore)
        constraints.append(contentsOf: [reviewScore.topAnchor.constraint(equalTo: reviewSiteLogo.bottomAnchor),
                                        reviewScore.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
                                        reviewScore.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
                                        reviewScore.heightAnchor.constraint(equalToConstant: 12.0)])
        addSubview(numberOfReviewersLabel)
        constraints.append(contentsOf: [numberOfReviewersLabel.topAnchor.constraint(equalTo: reviewScore.bottomAnchor),
                                        numberOfReviewersLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                        numberOfReviewersLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                        numberOfReviewersLabel.heightAnchor.constraint(equalToConstant: 18.0)])

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

}
