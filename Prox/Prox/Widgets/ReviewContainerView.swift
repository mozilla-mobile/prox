/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import QuartzCore

private let verticalMargin: CGFloat = 6

class ReviewContainerView: UIView {

    private let starImageAccessor: ProviderStarImageAccessor

    var score: Float = 0 {
        didSet {
            reviewScore.image = starImageAccessor.image(forScore: score)
        }
    }

    lazy var reviewSiteLogo: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let reviewScore: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }()

    lazy var numberOfReviewersLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()

    init(score: Float = 0, starImageAccessor: ProviderStarImageAccessor) {
        self.score = score
        self.starImageAccessor = starImageAccessor

        super.init(frame: .zero)
        setupSubviews()
        numberOfReviewersLabel.font = Fonts.detailsViewReviewerText
        numberOfReviewersLabel.textColor = Colors.detailsViewCardSecondaryText
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        for view in [reviewSiteLogo, reviewScore, numberOfReviewersLabel] as [UIView] {
            addSubview(view)
        }

        var constraints = [reviewSiteLogo.topAnchor.constraint(equalTo: self.topAnchor),
                           reviewSiteLogo.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                           reviewSiteLogo.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                           reviewSiteLogo.heightAnchor.constraint(equalToConstant: 28)]

        constraints.append(contentsOf: [reviewScore.topAnchor.constraint(equalTo: reviewSiteLogo.bottomAnchor, constant: verticalMargin),
                                        reviewScore.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                        reviewScore.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                        reviewScore.heightAnchor.constraint(equalToConstant: 20),])

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
