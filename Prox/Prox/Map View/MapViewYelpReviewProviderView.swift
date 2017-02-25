/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class MapViewYelpReviewProviderView: UIView, MapViewReviewProviderView {

    let scoreView = UIImageView()
    let reviewCountView = UILabel()

    let assetSize = CGSize(width: 132, height: 24)

    init() {
        super.init(frame: .zero)
        initViews(withParent: self)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func provider(from place: Place) -> PlaceProvider? { return place.yelpProvider }

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
