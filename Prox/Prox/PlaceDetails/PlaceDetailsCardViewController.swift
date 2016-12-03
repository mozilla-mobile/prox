/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import FXPageControl
import UIKit

private let  PlaceDetailsCardCellReuseIdentifier = "ImageCarouselCell"

protocol PlaceDetailsImageDelegate: class {
    func imageCarousel(imageCarousel: UIView, placeImageDidChange newImageURL: URL)
}

class PlaceDetailsCardViewController: UIViewController {

    var place: Place! {
        didSet {
            setPlace(place: place)
        }
    }

    weak var placeImageDelegate: PlaceDetailsImageDelegate?
    weak var locationProvider: LocationProvider? {
        didSet {
            self.setLocation(location: locationProvider?.getCurrentLocation())
        }
    }

    lazy var cardView: PlaceDetailsCardView = {
        let view = PlaceDetailsCardView()
        return view
    }()

    fileprivate lazy var imageCarouselLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        return layout
    }()

    fileprivate lazy var imageCarouselCollectionView: UICollectionView = {
        let collectionView = TouchableCollectionView(frame: .zero, collectionViewLayout: self.imageCarouselLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageCarouselCollectionViewCell.self, forCellWithReuseIdentifier: PlaceDetailsCardCellReuseIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.delaysContentTouches = false
        collectionView.touchDetected = { self.stopAutoMovingOfCarousel() }
        return collectionView
    }()

    lazy var pageControl: FXPageControl = {
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

    lazy var imageCarousel: UIView = {
        let imageCarousel = UIView()

        imageCarousel.accessibilityIdentifier = "PlaceImageCarousel"
        imageCarousel.backgroundColor = .white

        imageCarousel.addSubview(self.imageCarouselCollectionView)
        var constraints = [self.imageCarouselCollectionView.topAnchor.constraint(equalTo: imageCarousel.topAnchor),
                           self.imageCarouselCollectionView.leadingAnchor.constraint(equalTo: imageCarousel.leadingAnchor),
                           self.imageCarouselCollectionView.trailingAnchor.constraint(equalTo: imageCarousel.trailingAnchor),
                           self.imageCarouselCollectionView.bottomAnchor.constraint(equalTo: imageCarousel.bottomAnchor)]

        imageCarousel.addSubview(self.pageControl)
        constraints += [self.pageControl.bottomAnchor.constraint(equalTo: imageCarousel.bottomAnchor, constant: -40),
                        self.pageControl.centerXAnchor.constraint(equalTo: imageCarousel.centerXAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)

        return imageCarousel
    }()

    fileprivate var carouselTimer: Timer?

    init(place: Place) {
        self.place = place
        super.init(nibName: nil, bundle: nil)

        setPlace(place: place)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func showEvent() {
        self.cardView.showEvent(atPlace: place)
    }

    // TODO: set the view values in cardView to values in place
    fileprivate func setPlace(place: Place?) {
        guard let place = place else {
            return
        }
        imageCarouselCollectionView.reloadData()
        cardView.updateUI(forPlace: place)

        setLocation(location: locationProvider?.getCurrentLocation())
        setupCardInteractions()

        pageControl.numberOfPages = place.photoURLs.count
    }

    private func setLocation(location: CLLocation?) {
        PlaceUtilities.updateTravelTimeUI(fromPlace: place, toLocation: location, forView: cardView.travelTimeView)
        if let location = location {
            if let event = self.place.events.first {
                // check that travel times are within current location limits before deciding whether to send notification
                TravelTimesProvider.canTravelFrom(fromLocation: location.coordinate, toLocation: place.latLong, before: event.arrivalByTime()) { canTravel in
                    guard canTravel else { return }
                    DispatchQueue.main.async {
                        self.cardView.showEvent(atPlace: self.place)
                    }
                }
            }
        }
    }

    private func setupCardInteractions() {
        cardView.urlLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openPlaceURL(gestureRecgonizer:))))
        cardView.yelpReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openYelpReview(gestureRecgonizer:))))
        cardView.tripAdvisorReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openTripAdvisorReview(gestureRecgonizer:))))
        cardView.travelTimeView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openDirections(gestureRecgonizer:))))
        cardView.eventView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openEventURL(gestureRecognizer:))))
        cardView.wikiDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openWikipediaURL(gestureRecognizer:))))
        cardView.tripAdvisorDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openTripAdvisorReview(gestureRecgonizer:))))
        cardView.yelpDescriptionView.readMoreLink.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openYelpReview(gestureRecgonizer:))))
    }

    @objc private func openPlaceURL(gestureRecgonizer: UITapGestureRecognizer) {
        guard let urlString = place.url,
           let url = URL(string: urlString) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open web address")
        } else {
            Analytics.logEvent(event: AnalyticsEvent.WEBSITE, params: [:])
        }
    }

    @objc private func openYelpReview(gestureRecgonizer: UITapGestureRecognizer) {
        guard let url = URL(string: place.yelpProvider.url) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open yelp review")
        } else {
            Analytics.logEvent(event: AnalyticsEvent.YELP, params: [:])
        }
    }

    @objc private func openTripAdvisorReview(gestureRecgonizer: UITapGestureRecognizer) {
        guard let tripAdvisorProvider = place.tripAdvisorProvider,
            let url = URL(string: tripAdvisorProvider.url) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open trip advisor review")
        } else {
            Analytics.logEvent(event: AnalyticsEvent.TRIPADVISOR, params: [:])
        }
    }

    @objc private func openDirections(gestureRecgonizer: UITapGestureRecognizer) {
        guard let location = locationProvider?.getCurrentLocation(),
            let transportString = cardView.travelTimeView.secondaryTextLabel.text else { return }
        let transportType = transportString == "Walking" ? MKDirectionsTransportType.walking : MKDirectionsTransportType.automobile

        if !OpenInHelper.openRoute(fromLocation: location.coordinate, toPlace: place, by: transportType) {
            print("lol unable to open travel directions")
        } else {
            Analytics.logEvent(event: AnalyticsEvent.DIRECTIONS, params: [AnalyticsEvent.PARAM_ACTION: transportString])
        }
    }

    @objc private func openEventURL(gestureRecognizer: UITapGestureRecognizer) {
        guard let event = place.events.first,
            let urlString = event.url,
            let url = URL(httpStringMaybeWithScheme: urlString) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open web address")
        } else {
            Analytics.logEvent(event: AnalyticsEvent.EVENT_BANNER_LINK, params: [:])
        }
    }

    @objc private func openWikipediaURL(gestureRecognizer: UITapGestureRecognizer) {
        guard let wikipediaProvider = place.wikipediaProvider,
            let url = URL(string: wikipediaProvider.url) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open wikipedia review")
        }
    }

    private func getNextCarouselPageIndex() -> Int {
        var nextIndex = pageControl.currentPage + 1
        if nextIndex >= place.photoURLs.count {
            nextIndex = 0
        }
        return nextIndex
    }

    @objc private func autoMoveToNextCarouselImage() {
        self.imageCarouselCollectionView.scrollToItem(at: IndexPath(item: getNextCarouselPageIndex(), section: 0), at: UICollectionViewScrollPosition.centeredHorizontally, animated: true)
    }

    func pageControlDidPage(sender: AnyObject) {
        stopAutoMovingOfCarousel()
        self.imageCarouselCollectionView.scrollToItem(at: IndexPath(item: getNextCarouselPageIndex(), section: 0), at: UICollectionViewScrollPosition.centeredHorizontally, animated: true)
    }

    func beginAutoMovingOfCarousel() {
        carouselTimer = Timer.scheduledTimer(timeInterval: 6, target: self,
                                             selector: #selector(autoMoveToNextCarouselImage), userInfo: nil,
                                             repeats: true)
    }

    func stopAutoMovingOfCarousel() {
        carouselTimer?.invalidate()
        carouselTimer = nil
    }

    fileprivate func notifyDelegateOfChangeOfImageToURL(atIndex index: Int) {
        if index < place.photoURLs.count,
            let imageURL = URL(string: place.photoURLs[index]) {
            placeImageDelegate?.imageCarousel(imageCarousel: imageCarousel, placeImageDidChange: imageURL)
        }
    }
}

extension PlaceDetailsCardViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return place.photoURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PlaceDetailsCardCellReuseIdentifier, for: indexPath) as! ImageCarouselCollectionViewCell

        let placeholder = UIImage(named: "cardview_image_loading")
        if let photoURL = URL(string: place.photoURLs[indexPath.item]) {
            cell.imageView.setImageWith(photoURL, placeholderImage: placeholder)
        } else {
            cell.imageView.image = placeholder
        }
        return cell
    }
}

extension PlaceDetailsCardViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
}

extension PlaceDetailsCardViewController: UIScrollViewDelegate {
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        didChangePage(scrollView: scrollView)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        didChangePage(scrollView: scrollView)
    }

    fileprivate func didChangePage(scrollView: UIScrollView) {
        let pageSize = imageCarouselCollectionView.bounds.size

        // There isn't anything to page if the image carousel is empty
        guard pageSize != CGSize.zero && pageSize.width != 0 else {
            return
        }
        
        let selectedPageIndex = Int(floor((scrollView.contentOffset.x-pageSize.width/2)/pageSize.width))+1
        pageControl.currentPage = selectedPageIndex

        notifyDelegateOfChangeOfImageToURL(atIndex: selectedPageIndex)
    }
}

fileprivate class TouchableCollectionView: UICollectionView {
    var touchDetected: (() -> Void)?

    fileprivate override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchDetected?()
    }
}
