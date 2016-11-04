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

        if !isCellReused(cell) {
            cell.yelpReview.reviewSiteLogo.image = UIImage(named: "logo_yelp")
            cell.tripAdvisorReview.reviewSiteLogo.image = UIImage(named: "logo_ta")
        }

        // TODO: this view is only partially filled in
        guard let dataSource = dataSource,
            let place = try? dataSource.place(forIndex: indexPath.item) else {
            return cell
        }

        cell.category.text = PlaceUtilities.getString(forCategories: place.categories)
        cell.name.text = place.name

        cell.placeImage.image = UIImage(named: "place-placeholder") // TODO: placeholder w/o pop-in
        downloadAndSetImage(for: place, into: cell)

        PlaceUtilities.updateReviewUI(fromProvider: place.yelpProvider, onView: cell.yelpReview)
        PlaceUtilities.updateReviewUI(fromProvider: place.tripAdvisorProvider, onView: cell.tripAdvisorReview)

        if let location = locationProvider?.getCurrentLocation() {
            place.travelTimes(fromLocation: location, withCallback: { travelTimes in
                self.setTravelTimes(travelTimes: travelTimes, forCell: cell)
            })
        }

        return cell
    }

    private func isCellReused(_ cell: PlaceCarouselCollectionViewCell) -> Bool {
        return cell.yelpReview.reviewSiteLogo.image != nil
    }

    private func downloadAndSetImage(for place: Place, into cell: PlaceCarouselCollectionViewCell) {
        guard let urlStr = place.photoURLs?.first, let url = URL(string: urlStr) else {
            print("lol unable to create URL from photo url")
            return
        }

        let request = URLRequest(url: url)
        imageDownloader.downloadImage(for: request, success: { (urlReq, urlRes, img) in
            guard let res = urlRes else {
                print("lol urlRes unexpectedly null")
                return
            }

            guard res.statusCode == 200 else {
                print("lol image status code unexpectedly \(res.statusCode)")
                return
            }

            cell.placeImage.image = img
        }, failure: { (urlReq, urlRes, err) in
            print("lol unable to download photo: \(err)")
        })
    }

    private func setTravelTimes(travelTimes: TravelTimes?, forCell cell: PlaceCarouselCollectionViewCell) {
        guard let travelTimes = travelTimes else {
            return
        }

        if let walkingTimeSeconds = travelTimes.walkingTime {
            let walkingTimeMinutes = Int(round(walkingTimeSeconds / 60.0))
            if walkingTimeMinutes <= TravelTimesProvider.MIN_WALKING_TIME {
                if walkingTimeMinutes < TravelTimesProvider.YOU_ARE_HERE_WALKING_TIME {
                    cell.locationImage.image = UIImage(named: "icon_location")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
                    cell.location.text = "You're here"
                    cell.isSelected = true
                } else {
                    cell.location.text = "\(walkingTimeMinutes) min walk away"
                    cell.isSelected = false
                }
                return
            }
        }

        if let drivingTimeSeconds = travelTimes.drivingTime {
            let drivingTimeMinutes = Int(round(drivingTimeSeconds / 60.0))
            cell.location.text = "\(drivingTimeMinutes) min drive away"
            cell.isSelected = false
        }
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
