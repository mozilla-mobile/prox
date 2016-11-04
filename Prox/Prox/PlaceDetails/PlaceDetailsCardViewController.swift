/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.imageCarouselLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageCarouselCollectionViewCell.self, forCellWithReuseIdentifier: PlaceDetailsCardCellReuseIdentifier)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        return collectionView
    }()


    lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.pageIndicatorTintColor = Colors.pageIndicatorTintColor
        pageControl.currentPageIndicatorTintColor = Colors.currentPageIndicatorTintColor
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

    // TODO: set the view values in cardView to values in place
    fileprivate func setPlace(place: Place?) {
        guard let place = place else {
            return
        }
        cardView.updateUI(forPlace: place)
        setLocation(location: locationProvider?.getCurrentLocation())
        setupCardInteractions()

        pageControl.numberOfPages = place.photoURLs?.count ?? 0
    }

    private func setLocation(location: CLLocation?) {
        self.cardView.travelTimeView.loadingSpinner.startAnimating()
        if let location = location {
            place.travelTimes(fromLocation: location, withCallback: { travelTimes in
                guard let travelTimes = travelTimes else { return }
                self.cardView.travelTimeView.loadingSpinner.stopAnimating()
                self.cardView.updateTravelTimesUI(travelTimes: travelTimes)
            })
        }
    }

    private func setupCardInteractions() {
        cardView.urlLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openPlaceURL(gestureRecgonizer:))))
        cardView.yelpReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openYelpReview(gestureRecgonizer:))))
        cardView.tripAdvisorReviewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openTripAdvisorReview(gestureRecgonizer:))))
        cardView.travelTimeView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openDirections(gestureRecgonizer:))))
    }

    @objc private func openPlaceURL(gestureRecgonizer: UITapGestureRecognizer) {
        guard let urlString = place.url,
           let url = URL(string: urlString) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open web address")
        }
    }

    @objc private func openYelpReview(gestureRecgonizer: UITapGestureRecognizer) {
        guard let yelpProvider = place.yelpProvider,
            let url = URL(string: yelpProvider.url) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open yelp review")
        }
    }

    @objc private func openTripAdvisorReview(gestureRecgonizer: UITapGestureRecognizer) {
        guard let tripAdvisorProvider = place.tripAdvisorProvider,
            let url = URL(string: tripAdvisorProvider.url) else { return }
        if !OpenInHelper.open(url: url) {
            print("lol unable to open trip advisor review")
        }
    }

    @objc private func openDirections(gestureRecgonizer: UITapGestureRecognizer) {
        guard let location = locationProvider?.getCurrentLocation(),
            let transportString = cardView.travelTimeView.secondaryTextLabel.text else { return }
        let transportType = transportString == "Walking" ? MKDirectionsTransportType.walking : MKDirectionsTransportType.automobile

        if !OpenInHelper.openRoute(fromLocation: location.coordinate, toPlace: place, by: transportType) {
            print("lol unable to open travel directions")
        }
    }

    func pageControlDidPage(sender: AnyObject) {
        let pageSize = imageCarousel.bounds.size
        let xOffset = pageSize.width * CGFloat(pageControl.currentPage)
        imageCarouselCollectionView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
        notifyDelegateOfChangeOfImageToURL(atIndex: pageControl.currentPage)
    }

    fileprivate func notifyDelegateOfChangeOfImageToURL(atIndex index: Int) {
        if let imageURLString = place.photoURLs?[index],
            let imageURL = URL(string: imageURLString) {
            placeImageDelegate?.imageCarousel(imageCarousel: imageCarousel, placeImageDidChange: imageURL)
        }
    }
}

extension PlaceDetailsCardViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return place.photoURLs?.count ?? 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PlaceDetailsCardCellReuseIdentifier, for: indexPath) as! ImageCarouselCollectionViewCell
        if let photoURLs = place.photoURLs,
            let photoURL = URL(string: photoURLs[indexPath.item]) {
            cell.imageView.setImageWith(photoURL)

        } else {
            cell.imageView.image = UIImage(named: "place-placeholder")
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
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageSize = imageCarouselCollectionView.bounds.size
        let selectedPageIndex = Int(floor((scrollView.contentOffset.x-pageSize.width/2)/pageSize.width))+1
        pageControl.currentPage = Int(selectedPageIndex)

        notifyDelegateOfChangeOfImageToURL(atIndex: selectedPageIndex)
    }
}
