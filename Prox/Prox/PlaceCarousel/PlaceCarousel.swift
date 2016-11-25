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

    let defaultPadding: CGFloat = 15.0

    weak var delegate: PlaceCarouselDelegate?
    weak var dataSource: PlaceDataSource?
    weak var locationProvider: LocationProvider?

    private lazy var carouselLayout: UICollectionViewFlowLayout = {
        let layout = CarouselFlowLayout()
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
        carousel.collectionViewLayout.invalidateLayout()
    }

    func visibleCellFor(place: Place) -> PlaceCarouselCollectionViewCell? {
        guard let indexPath = indexPathFor(place: place) else {
           return nil
        }
        return carousel.cellForItem(at: indexPath) as? PlaceCarouselCollectionViewCell
    }

    func scrollTo(place: Place) {
        guard let indexPath = indexPathFor(place: place) else {
           return
        }
        carousel.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
    }

    fileprivate func indexPathFor(place: Place) -> IndexPath? {
        guard let index = dataSource?.index(forPlace: place) else {
            return nil
        }
        return IndexPath(item: index, section: 0)
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

fileprivate class CarouselFlowLayout: UICollectionViewFlowLayout {
    var pageWidth: CGFloat {
        return 200 + minimumLineSpacing
    }

    var flickVelocity: CGFloat {
        return 0.3
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init() {
        super.init()
    }

    fileprivate override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else {
            return CGPoint.zero
        }
        
        let rawPageValue = collectionView.contentOffset.x / pageWidth
        let currentPage = velocity.x > 0 ? floor(rawPageValue) : ceil(rawPageValue)
        let nextPage = velocity.x > 0 ? ceil(rawPageValue) : floor(rawPageValue)

        let pannedLessThanAPage = fabs(1 + currentPage - rawPageValue) > 0.5
        let flicked = fabs(velocity.x) > flickVelocity

        if pannedLessThanAPage && flicked {
            return CGPoint(x: nextPage * pageWidth, y: proposedContentOffset.y)
        } else {
            return CGPoint(x: round(rawPageValue) * pageWidth, y: proposedContentOffset.y)
        }
    }
}
