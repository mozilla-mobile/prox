/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class MapViewTripAdvisorReviewProviderView: UIView, MapViewReviewProviderView {

    let scoreView = UIImageView()
    let reviewCountView = UILabel()

    let assetSize = CGSize(width: 143, height: 24)

    init() {
        super.init(frame: .zero)
        initViews(withParent: self)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func provider(from place: Place) -> PlaceProvider? { return place.tripAdvisorProvider }

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
