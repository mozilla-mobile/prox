/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit


private let CellReuseIdentifier = "PlaceCarouselCell"

class PlaceCarousel: NSObject {

    var places: [Place] = [Place]()

    let defaultPadding: CGFloat = 15.0

    private lazy var carouselLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = self.defaultPadding
        layout.sectionInset = UIEdgeInsets(top: 0.0, left: self.defaultPadding, bottom: 0.0, right: self.defaultPadding)
        return layout
    }()

    lazy var carousel: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.carouselLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PlaceCarouselCollectionViewCell.self, forCellWithReuseIdentifier: CellReuseIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

}

extension PlaceCarousel: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseIdentifier, for: indexPath) as! PlaceCarouselCollectionViewCell
        cell.placeImage.image = UIImage(named: "place-placeholder")
        cell.category.text = "Hotel"
        cell.name.text = "Hilton Waikaloa Village"

        cell.yelpReview.score = 4
        cell.yelpReview.numberOfReviewersLabel.text = "647 Reviews"
        cell.yelpReview.reviewSiteLogo.image = UIImage(named: "logo_yelp")

        cell.tripAdvisorReview.score = 3
        cell.tripAdvisorReview.numberOfReviewersLabel.text = "6,665 Reviews"
        cell.tripAdvisorReview.reviewSiteLogo.image = UIImage(named: "logo_ta")

        if indexPath.item == 0 {
            cell.locationImage.image = UIImage(named: "icon_location")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
            cell.location.text = "You're here"
            cell.isSelected = true
        } else {
            cell.location.text = "17 min walk away"
            cell.isSelected = false
        }
        return cell
    }

}

extension PlaceCarousel: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 275)
    }

}
