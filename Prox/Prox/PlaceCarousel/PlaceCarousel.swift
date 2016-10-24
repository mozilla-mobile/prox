/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import AFNetworking

private let CellReuseIdentifier = "PlaceCarouselCell"
private let MIN_WALKING_TIME = 30
private let YOU_ARE_HERE_WALKING_TIME = 3

protocol PlaceCarouselDelegate: class {
    func placeCarousel(placeProvider: PlaceDataSource, didSelectPlace place: Place, atIndex index: Int)
}

protocol PlaceDataSource: class {
    func nextPlaceForPlace(place: Place) -> Place?
    func previousPlaceForPlace(place: Place) -> Place?
}

class PlaceCarousel: NSObject {

    var places: [Place] = [Place]() {
        didSet {
            // TODO: how do we make sure the user wasn't interacting?
            carousel.reloadData()
        }
    }

    lazy var imageDownloader: AFImageDownloader = {
        // TODO: Maybe we want more control over the configuration.
        let sessionManager = AFHTTPSessionManager(sessionConfiguration: .default)
        sessionManager.responseSerializer = AFImageResponseSerializer() // sets correct mime-type.

        let activeDownloadCount = 4 // TODO: value?
        let cache = AFAutoPurgingImageCache() // defaults 100 MB max -> 60 MB after purge
        return AFImageDownloader(sessionManager: sessionManager, downloadPrioritization: .FIFO,
                                 maximumActiveDownloads: activeDownloadCount, imageCache: cache)
    }()

    var currentLocation: CLLocation?

    let defaultPadding: CGFloat = 15.0

    weak var delegate: PlaceCarouselDelegate?

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
        return places.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // TODO: this view is only partially filled in
        let place = places[indexPath.item]

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseIdentifier, for: indexPath) as! PlaceCarouselCollectionViewCell
        cell.category.text = "Hotel"
        cell.name.text = place.name

        cell.placeImage.image = UIImage(named: "place-placeholder") // TODO: placeholder w/o pop-in
        downloadAndSetImage(for: place, into: cell)


        if let yelp = place.yelpProvider {
            // TODO: handle optionals in UI
            cell.yelpReview.score = Float(yelp.rating ?? -1)  // TODO: type
            cell.yelpReview.numberOfReviewersLabel.text = "\(yelp.totalReviewCount!) Reviews"
            cell.yelpReview.reviewSiteLogo.image = UIImage(named: "logo_yelp")
        }

        cell.tripAdvisorReview.score = 3.5
        cell.tripAdvisorReview.numberOfReviewersLabel.text = "6,665 Reviews"
        cell.tripAdvisorReview.reviewSiteLogo.image = UIImage(named: "logo_ta")

        if let travelTimes = place.travelTimes {
            self.setTravelTimes(travelTimes: travelTimes, forCell: cell)
        } else if let currentLocation = self.currentLocation {
            TravelTimesProvider.travelTime(fromLocation: currentLocation.coordinate, toLocation: place.latLong) { travelTimes in
                place.travelTimes = travelTimes

                DispatchQueue.main.async {
                    self.setTravelTimes(travelTimes: travelTimes, forCell: cell)
                }
            }
        }

        return cell
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
            if walkingTimeMinutes <= MIN_WALKING_TIME {
                if walkingTimeMinutes < YOU_ARE_HERE_WALKING_TIME {
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
        let place = places[indexPath.item]
        print("Selected place \(place.name)")
        delegate?.placeCarousel(placeProvider: self, didSelectPlace: place, atIndex: indexPath.row)
    }

}

extension PlaceCarousel: PlaceDataSource {
    
    func nextPlaceForPlace(place: Place) -> Place? {
        guard let currentPlaceIndex = places.index(where: {$0 == place}),
            currentPlaceIndex < places.endIndex else {
            return nil
        }

        return places[places.index(after: currentPlaceIndex)]
    }

    func previousPlaceForPlace(place: Place) -> Place? {
        guard let currentPlaceIndex = places.index(where: {$0 == place}),
            currentPlaceIndex > places.startIndex else {
                return nil
        }

        return places[places.index(before: currentPlaceIndex)]
    }
}
