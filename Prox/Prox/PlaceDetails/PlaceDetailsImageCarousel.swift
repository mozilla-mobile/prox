/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import FXPageControl

private let accessibilityIdentifier = "PlaceImageCarousel"
private let cardCellReuseIdentifier = "ImageCarouselCell"

protocol PlaceDetailsImageDelegate: class {
    func imageCarousel(imageCarousel: UIView, placeImageDidChange newImageURL: URL)
}

class PlaceDetailsImageCarousel: UIView {

    var place: Place {
        didSet { onPlaceSet() }
    }

    fileprivate var carouselTimer: Timer?

    weak var delegate: PlaceDetailsImageDelegate?

    fileprivate lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0

        let collectionView = TouchableCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageCarouselCollectionViewCell.self, forCellWithReuseIdentifier: cardCellReuseIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.delaysContentTouches = false
        collectionView.touchDetected = { self.stopAutoMove() }
        return collectionView
    }()

    fileprivate lazy var pageControl: FXPageControl = {
        let pageControl = FXPageControl()
        pageControl.backgroundColor = .clear
        pageControl.dotColor = Colors.pageIndicatorTintColor
        pageControl.selectedDotColor = Colors.currentPageIndicatorTintColor

        let shadowBlur: CGFloat = 3
        let shadowOffset = CGSize(width: 0.5, height: 0.75)
        let shadowColor = Colors.detailsViewImageCarouselPageControlShadow
        pageControl.dotShadowBlur = shadowBlur
        pageControl.selectedDotShadowBlur = shadowBlur
        pageControl.dotShadowColor = shadowColor
        pageControl.selectedDotShadowColor = shadowColor
        pageControl.dotShadowOffset = shadowOffset
        pageControl.selectedDotShadowOffset = shadowOffset

        pageControl.addTarget(self, action: #selector(self.pageControlDidPage(sender:)), for: UIControlEvents.valueChanged)
        return pageControl
    }()

    init(place: Place) {
        self.place = place
        super.init(frame: .zero)
        setupViews()
        onPlaceSet()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("no coder init") }

    private func onPlaceSet() {
        collectionView.reloadData()
        pageControl.numberOfPages = place.photoURLs.count
    }

    private func setupViews() {
        self.accessibilityIdentifier = accessibilityIdentifier
        backgroundColor = .white
        for subview in [collectionView, pageControl] as [UIView] { addSubview(subview) }

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        pageControl.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(40)
            make.centerX.equalToSuperview()
        }
    }

    func beginAutoMove() {
        carouselTimer = Timer.scheduledTimer(timeInterval: 6, target: self,
                                             selector: #selector(autoMoveToNextImage), userInfo: nil,
                                             repeats: true)
    }

    func stopAutoMove() {
        carouselTimer?.invalidate()
        carouselTimer = nil
    }

    @objc private func autoMoveToNextImage() {
        collectionView.scrollToItem(at: IndexPath(item: getNextCarouselPageIndex(), section: 0), at: UICollectionViewScrollPosition.centeredHorizontally, animated: true)
    }

    @objc private func pageControlDidPage(sender: AnyObject) {
        stopAutoMove()
        collectionView.scrollToItem(at: IndexPath(item: getNextCarouselPageIndex(), section: 0), at: UICollectionViewScrollPosition.centeredHorizontally, animated: true)
    }

    private func getNextCarouselPageIndex() -> Int {
        var nextIndex = pageControl.currentPage + 1
        if nextIndex >= place.photoURLs.count {
            nextIndex = 0
        }
        return nextIndex
    }
}

fileprivate class TouchableCollectionView: UICollectionView {
    var touchDetected: (() -> Void)?

    fileprivate override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchDetected?()
    }
}

extension PlaceDetailsImageCarousel: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
}

extension PlaceDetailsImageCarousel: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return place.photoURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cardCellReuseIdentifier, for: indexPath) as! ImageCarouselCollectionViewCell

        let placeholder = UIImage(named: "cardview_image_loading")
        let photoURL = place.photoURLs[indexPath.item]
        cell.imageView.setImageWith(photoURL, placeholderImage: placeholder)
        return cell
    }
}

extension PlaceDetailsImageCarousel: UIScrollViewDelegate {
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        didChangePage(scrollView: scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        didChangePage(scrollView: scrollView)
    }

    fileprivate func didChangePage(scrollView: UIScrollView) {
        let pageSize = bounds.size

        // There isn't anything to page if the image carousel is empty
        guard pageSize != CGSize.zero && pageSize.width != 0 else {
            return
        }

        let selectedPageIndex = Int(floor((scrollView.contentOffset.x-pageSize.width/2)/pageSize.width))+1
        pageControl.currentPage = selectedPageIndex

        notifyDelegateOfChangeOfImageToURL(atIndex: selectedPageIndex)
    }

    fileprivate func notifyDelegateOfChangeOfImageToURL(atIndex index: Int) {
        if index < place.photoURLs.count {
            let imageURL = place.photoURLs[index]
            delegate?.imageCarousel(imageCarousel: self, placeImageDidChange: imageURL)
        }
    }
}
