/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking
import BadgeSwift

private let CellReuseIdentifier = "ImageCarouselCell"

class PlaceDetailViewController: UIViewController {

    fileprivate let place: Place
    weak var dataSource: PlaceDataSource? {
        didSet {
            mapButtonBadge.text = "\(dataSource?.numberOfPlaces() ?? 0)"
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

    // TODO: make carousel
    private lazy var imageCarouselLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        return layout
    }()

    lazy var imageCarousel: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.imageCarouselLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ImageCarouselCollectionViewCell.self, forCellWithReuseIdentifier: CellReuseIdentifier)
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

    lazy var cardView: PlaceDetailsCardView = {
        let view = PlaceDetailsCardView()
        return view
    }()

    lazy var mapButton: MapButton = {
        let button = MapButton()
        button.setImage(UIImage(named: "icon_mapview"), for: .normal)
        button.addTarget(self, action: #selector(self.close), for: .touchUpInside)
        button.clipsToBounds = false
        return button
    }()

    lazy var mapButtonBadge: BadgeSwift = {
        let badge = BadgeSwift()
        badge.font = UIFont.systemFont(ofSize: 14)
        badge.badgeColor = UIColor(colorLiteralRed: 0.07, green: 0.40, blue: 0.98, alpha: 1.0)
        badge.textColor = UIColor.white
        badge.shadowOpacityBadge = 0.5
        badge.shadowOffsetBadge = CGSize(width: 0, height: 0)
        badge.shadowRadiusBadge = 1.0
        badge.shadowColorBadge = UIColor.black
        return badge
    }()

    init(place: Place) {
        self.place = place
        super.init(nibName: nil, bundle: nil)

        pageControl.numberOfPages = place.photoURLs?.count ?? 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0.5, alpha: 1) // TODO: blurred image background

        view.addSubview(imageCarousel)
        var constraints = [imageCarousel.topAnchor.constraint(equalTo: view.topAnchor),
                           imageCarousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           imageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           imageCarousel.heightAnchor.constraint(equalToConstant: 240)]

        view.addSubview(pageControl)
        constraints += [pageControl.bottomAnchor.constraint(equalTo: imageCarousel.bottomAnchor, constant: -40),
            pageControl.centerXAnchor.constraint(equalTo: imageCarousel.centerXAnchor)]

        view.addSubview(cardView)
        constraints += [cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 204),
                        cardView.widthAnchor.constraint(equalToConstant: 343),
                        cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)]

        view.addSubview(mapButton)
        constraints += [mapButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
                        mapButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                        mapButton.heightAnchor.constraint(equalToConstant: 48),
                        mapButton.widthAnchor.constraint(equalToConstant: 48)]

        view.addSubview(mapButtonBadge)
        constraints += [mapButtonBadge.leadingAnchor.constraint(equalTo: mapButton.trailingAnchor, constant: -10),
                        mapButtonBadge.topAnchor.constraint(equalTo: mapButton.topAnchor),
                        mapButtonBadge.heightAnchor.constraint(equalToConstant: 20.0),
                        mapButtonBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20.0)]


        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func pageControlDidPage(sender: AnyObject) {
        let pageSize = imageCarousel.bounds.size
        let xOffset = pageSize.width * CGFloat(pageControl.currentPage)
        imageCarousel.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
    }

    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension PlaceDetailViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return place.photoURLs?.count ?? 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseIdentifier, for: indexPath) as! ImageCarouselCollectionViewCell
        if let photoURLs = place.photoURLs,
            let photoURL = URL(string: photoURLs[indexPath.item]) {
            cell.imageView.setImageWith(photoURL)

        } else {
            cell.imageView.image = UIImage(named: "place-placeholder")
        }
        return cell
    }
}

extension PlaceDetailViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
}

extension PlaceDetailViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageSize = imageCarousel.bounds.size
        let selectedPageIndex = Int(floor((scrollView.contentOffset.x-pageSize.width/2)/pageSize.width))+1
        pageControl.currentPage = Int(selectedPageIndex)
    }
}
