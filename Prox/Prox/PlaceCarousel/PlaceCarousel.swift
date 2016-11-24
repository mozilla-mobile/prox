/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import AFNetworking

private let CellReuseIdentifier = "PlaceCarouselCell"

protocol PlaceCarouselDelegate: class {
    func placeCarousel(placeCarousel: PlaceCarousel, didSelectPlaceAtIndex index: Int)
}

class PlaceCarousel: NSObject {

    lazy var imageDownloader: AFImageDownloader = {
        // TODO: Maybe we want more control over the configuration.
        let sessionManager = AFHTTPSessionManager(sessionConfiguration: .default)
        sessionManager.responseSerializer = AFImageResponseSerializer() // sets correct mime-type.

        let activeDownloadCount = 4 // TODO: value?
        let cache = AFAutoPurgingImageCache() // defaults 100 MB max -> 60 MB after purge
        return AFImageDownloader(sessionManager: sessionManager, downloadPrioritization: .FIFO,
                                 maximumActiveDownloads: activeDownloadCount, imageCache: cache)
    }()

    let defaultPadding: CGFloat = 15.0

    weak var delegate: PlaceCarouselDelegate?
    weak var dataSource: PlaceDataSource?
    weak var locationProvider: LocationProvider?

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

    func refresh() {
        carousel.reloadData()
    }

}

extension PlaceCarousel: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.numberOfPlaces() ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseIdentifier, for: indexPath) as! PlaceCarouselCollectionViewCell

        // TODO: this view is only partially filled in
        guard let dataSource = dataSource,
            let place = try? dataSource.place(forIndex: indexPath.item) else {
            return cell
        }

        cell.category.text = PlaceUtilities.getString(forCategories: place.categories.names)
        cell.name.text = place.name

        downloadAndSetImage(for: place, into: cell)

        PlaceUtilities.updateReviewUI(fromProvider: place.yelpProvider, onView: cell.yelpReview, isTextShortened: true)
        PlaceUtilities.updateReviewUI(fromProvider: place.tripAdvisorProvider, onView: cell.tripAdvisorReview, isTextShortened: true)

        PlaceUtilities.updateTravelTimeUI(fromPlace: place, toLocation: locationProvider?.getCurrentLocation(), forView: cell)

        return cell
    }

    private func downloadAndSetImage(for place: Place, into cell: PlaceCarouselCollectionViewCell) {
        // Prepare for re-use.
        cell.placeImage.cancelImageDownloadTask()
        cell.placeImage.image = UIImage(named: "carousel_image_loading")

        guard let urlStr = place.photoURLs.first, let url = URL(string: urlStr) else {
            print("lol unable to create URL from photo url")
            return
        }

        cell.placeImage.setImageWith(url)
    }
}

extension PlaceCarousel: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 275)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.placeCarousel(placeCarousel: self, didSelectPlaceAtIndex: indexPath.item)
    }

}
