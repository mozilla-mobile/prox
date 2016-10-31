/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking
import BadgeSwift

private let CellReuseIdentifier = "ImageCarouselCell"

class PlaceDetailViewController: UIViewController {

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

    fileprivate var previousCardViewController: PlaceDetailsCardViewController?
    fileprivate var currentCardViewController: PlaceDetailsCardViewController
    fileprivate var nextCardViewController: PlaceDetailsCardViewController?

    fileprivate lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(gestureRecognizer:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        return panGesture
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
        badge.font = Fonts.detailsViewMapButtonBadgeText
        badge.badgeColor = Colors.detailsViewMapButtonBadgeBackground
        badge.textColor = Colors.detailsViewMapButtonBadgeFont
        badge.shadowOpacityBadge = 0.5
        badge.shadowOffsetBadge = CGSize(width: 0, height: 0)
        badge.shadowRadiusBadge = 1.0
        badge.shadowColorBadge = Colors.detailsViewMapButtonShadow
        return badge
    }()

    fileprivate var currentCardViewCenterXConstraint: NSLayoutConstraint?
    fileprivate var previousCardViewTrailingConstraint: NSLayoutConstraint?
    fileprivate var nextCardViewLeadingConstraint: NSLayoutConstraint?


    init(place: Place) {
        self.currentCardViewController = PlaceDetailsCardViewController(place: place)
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

        view.addSubview(currentCardViewController.cardView)
        currentCardViewCenterXConstraint = currentCardViewController.cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        constraints += [currentCardViewController.cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 204),
                        currentCardViewController.cardView.widthAnchor.constraint(equalToConstant: 343),
                        currentCardViewCenterXConstraint!]
        self.addChildViewController(currentCardViewController)

        // add a pan gesture recognizer to the current place card
        currentCardViewController.cardView.addGestureRecognizer(panGestureRecognizer)


        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardViewController.place) {
            previousCardViewController = PlaceDetailsCardViewController(place: previousPlace)
            previousCardViewController?.setPlace(place: previousPlace)
            view.addSubview(previousCardViewController!.cardView)
            previousCardViewTrailingConstraint = previousCardViewController!.cardView.trailingAnchor.constraint(equalTo: currentCardViewController.cardView.leadingAnchor, constant: -6)
            constraints += [previousCardViewController!.cardView.topAnchor.constraint(equalTo: currentCardViewController.cardView.topAnchor),
                            previousCardViewController!.cardView.widthAnchor.constraint(equalTo: currentCardViewController.cardView.widthAnchor),
                            previousCardViewTrailingConstraint!]
        }

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardViewController.place) {
            nextCardViewController = PlaceDetailsCardViewController(place: nextPlace)
            nextCardViewController?.setPlace(place: nextPlace)
            view.addSubview(nextCardViewController!.cardView)
            nextCardViewLeadingConstraint = nextCardViewController!.cardView.leadingAnchor.constraint(equalTo: currentCardViewController.cardView.trailingAnchor, constant: 6)
            constraints += [nextCardViewController!.cardView.topAnchor.constraint(equalTo: currentCardViewController.cardView.topAnchor),
                            nextCardViewController!.cardView.widthAnchor.constraint(equalTo: currentCardViewController.cardView.widthAnchor),
                            nextCardViewLeadingConstraint!]
        }

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

    var startConstant: CGFloat!

    func didPan(gestureRecognizer: UIPanGestureRecognizer) {

        if gestureRecognizer.state == .began {
            startConstant = currentCardViewCenterXConstraint?.constant ?? 0
        }

        let translationX = gestureRecognizer.translation(in: self.view).x

        if gestureRecognizer.state == .ended {
            let velocityX = (0.2 * gestureRecognizer.velocity(in: self.view).x)
            let finalX = translationX + velocityX

            let newCenter = currentCardViewCenterXConstraint?.constant ?? 0

            let animationDuration = (abs(velocityX) * 0.002) + 0.2

            let animationCompletion: ((Bool) -> ())?

            if newCenter < -(self.view.frame.width * 0.5),
                let nextCardViewController = nextCardViewController {
                print("Over threshold. Scroll should autocomplete left")
                // check to see if there is a next card to the next card
                // add a new view controller to next card view controller
                // if so, remove currentCardViewController centerX constraint
                // add center x constraint to nextCardViewController

                var newNextCardViewController: PlaceDetailsCardViewController? = nil

                var constraintsToActivate = [NSLayoutConstraint]()
                var constraintsToDeactivate = [NSLayoutConstraint]()

                // deactivate and remove current view controller center constraint
                if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
                    constraintsToDeactivate += [currentCardViewCenterXConstraint]
                }
                self.currentCardViewCenterXConstraint = nextCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
                constraintsToActivate += [self.currentCardViewCenterXConstraint!]
                // deactivate and remove next view controller leading constraint
                if let nextCardViewLeadingConstraint = nextCardViewLeadingConstraint {
                    constraintsToDeactivate += [nextCardViewLeadingConstraint]
                }

                if let newNext = dataSource?.nextPlace(forPlace: nextCardViewController.place) {
                    newNextCardViewController = PlaceDetailsCardViewController(place:newNext)
                    self.view.addSubview(newNextCardViewController!.cardView)
                    self.addChildViewController(newNextCardViewController!)
                    self.nextCardViewLeadingConstraint = newNextCardViewController!.cardView.leadingAnchor.constraint(equalTo: nextCardViewController.cardView.trailingAnchor, constant: 6)
                    constraintsToActivate += [self.nextCardViewLeadingConstraint!]
                } else {
                    nextCardViewLeadingConstraint = nil
                }
                // create new previous view controller trailing constraint
                if let previousCardViewTrailingConstraint = previousCardViewTrailingConstraint {
                    constraintsToDeactivate += [previousCardViewTrailingConstraint]
                }
                self.previousCardViewTrailingConstraint = currentCardViewController.cardView.trailingAnchor.constraint(equalTo: nextCardViewController.cardView.leadingAnchor, constant: -6)
                constraintsToActivate += [self.previousCardViewTrailingConstraint!]
                NSLayoutConstraint.deactivate(constraintsToDeactivate)
                NSLayoutConstraint.activate(constraintsToActivate, translatesAutoresizingMaskIntoConstraints: false)

                animationCompletion = { finished in
                    if finished {
                        self.currentCardViewController.cardView.removeGestureRecognizer(self.panGestureRecognizer)
                        self.previousCardViewController?.cardView.removeFromSuperview()
                        self.previousCardViewController?.removeFromParentViewController()
                        self.previousCardViewController = self.currentCardViewController
                        self.currentCardViewController = nextCardViewController
                        self.currentCardViewController.cardView.addGestureRecognizer(self.panGestureRecognizer)
                        self.nextCardViewController = newNextCardViewController
                    }
                }
            } else if newCenter > self.view.frame.width * 0.5,
                let previousCardViewController = previousCardViewController {
                print("Over threshold. Scroll should autocomplete left")
                // check to see if there is a previous card to the previous card
                // add a new view controller to previous card view controller
                // if so, remove currentCardViewController centerX constraint
                // add center x constraint to previousCardViewController
                var newPreviousCardViewController: PlaceDetailsCardViewController? = nil

                var constraintsToActivate = [NSLayoutConstraint]()
                var constraintsToDeactivate = [NSLayoutConstraint]()

                // deactivate and remove current view controller center constraint
                if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
                    constraintsToDeactivate += [currentCardViewCenterXConstraint]
                }
                self.currentCardViewCenterXConstraint = previousCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
                constraintsToActivate += [self.currentCardViewCenterXConstraint!]
                // deactivate and remove next view controller leading constraint
                if let nextCardViewLeadingConstraint = nextCardViewLeadingConstraint {
                    constraintsToDeactivate += [nextCardViewLeadingConstraint]
                }
                self.nextCardViewLeadingConstraint = currentCardViewController.cardView.leadingAnchor.constraint(equalTo: previousCardViewController.cardView.trailingAnchor, constant: 6)
                constraintsToActivate += [self.nextCardViewLeadingConstraint!]
                // create new previous view controller trailing constraint
                if let previousCardViewTrailingConstraint = previousCardViewTrailingConstraint {
                    constraintsToDeactivate += [previousCardViewTrailingConstraint]
                }

                if let newNext = dataSource?.previousPlace(forPlace: previousCardViewController.place) {
                    newPreviousCardViewController = PlaceDetailsCardViewController(place:newNext)
                    self.view.addSubview(newPreviousCardViewController!.cardView)
                    self.addChildViewController(newPreviousCardViewController!)
                    self.previousCardViewTrailingConstraint = newPreviousCardViewController!.cardView.trailingAnchor.constraint(equalTo: previousCardViewController.cardView.leadingAnchor, constant: -6)
                    constraintsToActivate += [self.previousCardViewTrailingConstraint!]
                } else {
                    previousCardViewTrailingConstraint = nil
                }

                NSLayoutConstraint.deactivate(constraintsToDeactivate)
                NSLayoutConstraint.activate(constraintsToActivate, translatesAutoresizingMaskIntoConstraints: false)

                animationCompletion = { finished in
                    if finished {
                        self.currentCardViewController.cardView.removeGestureRecognizer(self.panGestureRecognizer)
                        self.nextCardViewController?.cardView.removeFromSuperview()
                        self.nextCardViewController?.removeFromParentViewController()
                        self.nextCardViewController = self.currentCardViewController
                        self.currentCardViewController = previousCardViewController
                        self.currentCardViewController.cardView.addGestureRecognizer(self.panGestureRecognizer)
                        self.previousCardViewController = newPreviousCardViewController
                    }
                }
            } else {
                print("Under threshold. Scroll should unwind")
                currentCardViewCenterXConstraint?.constant = startConstant
                animationCompletion = nil
            }


            UIView.animate(withDuration: TimeInterval(animationDuration), delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
                self.view.layoutIfNeeded()
                }, completion: animationCompletion )
        } else {
            currentCardViewCenterXConstraint?.constant = startConstant + translationX
            view.updateConstraints()
        }
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
        return currentCardViewController.place.photoURLs?.count ?? 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellReuseIdentifier, for: indexPath) as! ImageCarouselCollectionViewCell
        if let photoURLs = currentCardViewController.place.photoURLs,
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
