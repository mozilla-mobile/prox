/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

// All items in the protocol could be static but I don't know how to do that in swift.
protocol ProviderStarImageAccessor {

    /// The size, in pixels, of the review score asset. Used for `widthConstraint(for:withViewHeight)`
    var assetSize: CGSize { get }
    func image(forScore score: Float) -> UIImage?
}

extension ProviderStarImageAccessor {

    /// Returns a width constraint that, when activated, constrains the image view to the asset size,
    /// based on the given height.
    ///
    /// HACK: when we scale inside a UIImageView, the UIImageView keeps the size the of the original image
    /// (rather than taking the scaled image size) so, in this case, the view is too wide and has whitespace
    /// on either side of the image. For dev speed, we hardcode the asset sizes and set width constraints
    /// with this method. A proper alternative would be to scale the image outside the image view
    /// and set the image view with the scaled image.
    func widthConstraint(for view: UIImageView, withViewHeight viewHeight: CGFloat) -> NSLayoutConstraint {
        let scoreViewWidth = (viewHeight / assetSize.height) * assetSize.width
        return view.widthAnchor.constraint(equalToConstant: scoreViewWidth)
    }
}

struct YelpStarImageAccessor: ProviderStarImageAccessor {
    let assetSize = CGSize(width: 132, height: 24)

    func image(forScore score: Float) -> UIImage? {
        let img: UIImage
        switch score {
        case 0: img = #imageLiteral(resourceName: "score_yelp_0") // Yelp has no 0.5 image - I guess you can only rate lowest 1 star.
        case 1..<1.5: img = #imageLiteral(resourceName: "score_yelp_1")
        case 1.5..<2: img = #imageLiteral(resourceName: "score_yelp_1_half")
        case 2..<2.5: img = #imageLiteral(resourceName: "score_yelp_2")
        case 2.5..<3: img = #imageLiteral(resourceName: "score_yelp_2_half")
        case 3..<3.5: img = #imageLiteral(resourceName: "score_yelp_3")
        case 3.5..<4: img = #imageLiteral(resourceName: "score_yelp_3_half")
        case 4..<4.5: img = #imageLiteral(resourceName: "score_yelp_4")
        case 4.5..<5: img = #imageLiteral(resourceName: "score_yelp_4_half")
        case 5: img = #imageLiteral(resourceName: "score_yelp_5")

        default:
            log.warn("Unexpected Yelp score \(score). Returning nil.")
            return nil
        }

        return img
    }
}

struct TripAdvisorStarImageAccessor: ProviderStarImageAccessor {
    let assetSize = CGSize(width: 143, height: 24)

    func image(forScore score: Float) -> UIImage? {
        let img: UIImage
        switch score {
        case 0..<0.5: img = #imageLiteral(resourceName: "score_ta_0")
        case 0.5..<1: img = #imageLiteral(resourceName: "score_ta_0_half")
        case 1..<1.5: img = #imageLiteral(resourceName: "score_ta_1")
        case 1.5..<2: img = #imageLiteral(resourceName: "score_ta_1_half")
        case 2..<2.5: img = #imageLiteral(resourceName: "score_ta_2")
        case 2.5..<3: img = #imageLiteral(resourceName: "score_ta_2_half")
        case 3..<3.5: img = #imageLiteral(resourceName: "score_ta_3")
        case 3.5..<4: img = #imageLiteral(resourceName: "score_ta_3_half")
        case 4..<4.5: img = #imageLiteral(resourceName: "score_ta_4")
        case 4.5..<5: img = #imageLiteral(resourceName: "score_ta_4_half")
        case 5: img = #imageLiteral(resourceName: "score_ta_5")

        default:
            log.warn("Unexpected TA score \(score). Returning nil.")
            return nil
        }

        return img
    }
}
