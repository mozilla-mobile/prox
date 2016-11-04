/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking
import BadgeSwift

enum PanDirection {
    case vertical, horizontal, none
}

/**
 * This class has essentially implemented it's own version of a paging collection view

 * The reason we have done this and not used either a UIPageViewController or a UICollectionViewController is as follows
 * * UIPageViewController does not allow for pages with width < screen size, so there is no option to have the edges of previous
 *   and next view controllers showing at the same time as the current view controller
 * * UICollectionViewController will give us the previous, but will not allow us to specify custom paging transition animations
 *
 *  By rolling this view controller by hand we get both the layout we want AND the custom paging animation
 **/
class PlaceDetailViewController: UIViewController {

    weak var dataSource: PlaceDataSource? {
        didSet {
            mapButtonBadge.text = "\(dataSource?.numberOfPlaces() ?? 0)"
        }
    }

    weak var locationProvider: LocationProvider? {
        didSet {
            self.currentCardViewController.locationProvider = locationProvider
        }
    }

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isScrollEnabled = false
        scrollView.contentSize = CGSize(width: 1, height: self.view.bounds.height)
        scrollView.bounces = false
        return scrollView
    }()

    lazy var imageDownloader: AFImageDownloader = {
        // TODO: Maybe we want more control over the configuration.
        let sessionManager = AFHTTPSessionManager(sessionConfiguration: .default)
        sessionManager.responseSerializer = AFImageResponseSerializer() // sets correct mime-type.

        let activeDownloadCount = 4 // TODO: value?
        let cache = AFAutoPurgingImageCache() // defaults 100 MB max -> 60 MB after purge
        return AFImageDownloader(sessionManager: sessionManager, downloadPrioritization: .FIFO,
                                 maximumActiveDownloads: activeDownloadCount, imageCache: cache)
    }()

    fileprivate lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(gestureRecognizer:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = self
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

    fileprivate var previousCardViewController: PlaceDetailsCardViewController?
    fileprivate var currentCardViewController: PlaceDetailsCardViewController!
    fileprivate var nextCardViewController: PlaceDetailsCardViewController?
    fileprivate var unusedPlaceCardViewControllers = [PlaceDetailsCardViewController]()

    fileprivate var currentCardViewCenterXConstraint: NSLayoutConstraint?
    fileprivate var previousCardViewTrailingConstraint: NSLayoutConstraint?
    fileprivate var nextCardViewLeadingConstraint: NSLayoutConstraint?
    fileprivate var backgroundImageHeightConstraint: NSLayoutConstraint?

    var imageCarousel: UIView!

    fileprivate let cardViewTopAnchorConstant: CGFloat = 204
    fileprivate let cardViewSpacingConstant: CGFloat = 6
    fileprivate let cardViewWidthConstant: CGFloat = 343
    fileprivate let imageCarouselHeightConstant: CGFloat = 240
    fileprivate let animationDurationConstant = 0.5
    fileprivate var startConstant: CGFloat!

    lazy var backgroundImage: UIImageView = {
        let view = UIImageView()
        return view
    }()

    lazy var backgroundBlurEffect: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        return blurEffectView
    }()

    fileprivate var panDirection: PanDirection = .none

    init(place: Place) {
        super.init(nibName: nil, bundle: nil)
        self.currentCardViewController = dequeuePlaceCardViewController(forPlace: place)
        setBackgroundImage(toPhotoAtURL: place.photoURLs?.first)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setBackgroundImage(toPhotoAtURL photoURLString: String?) {
        if let imageURLString = photoURLString,
            let imageURL = URL(string: imageURLString) {
            self.backgroundImage.setImageWith(imageURL)
        } else {
            backgroundImage.image = UIImage(named: "place-placeholder")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        var constraints = [scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                           scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        imageCarousel = currentCardViewController.imageCarousel
        scrollView.addSubview(backgroundImage)
        backgroundImage.addSubview(backgroundBlurEffect)
        scrollView.addSubview(imageCarousel)

        backgroundImageHeightConstraint = backgroundImage.heightAnchor.constraint(equalToConstant: scrollView.contentSize.height)

        constraints += [backgroundImage.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: imageCarouselHeightConstant),
                           backgroundImage.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                           backgroundImageHeightConstraint!,
                           backgroundImage.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        backgroundImage.addSubview(backgroundBlurEffect)
        constraints += [backgroundBlurEffect.topAnchor.constraint(equalTo: backgroundImage.topAnchor),
                       backgroundBlurEffect.leadingAnchor.constraint(equalTo: backgroundImage.leadingAnchor),
                       backgroundBlurEffect.bottomAnchor.constraint(equalTo: backgroundImage.bottomAnchor),
                       backgroundBlurEffect.trailingAnchor.constraint(equalTo: backgroundImage.trailingAnchor)]

        constraints += [imageCarousel.topAnchor.constraint(equalTo: scrollView.topAnchor),
                           imageCarousel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                           imageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           imageCarousel.heightAnchor.constraint(equalToConstant: imageCarouselHeightConstant)]

        scrollView.addSubview(currentCardViewController.cardView)
        currentCardViewCenterXConstraint = currentCardViewController.cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        constraints += [currentCardViewController.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                        currentCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidthConstant),
                        currentCardViewCenterXConstraint!]
        self.addChildViewController(currentCardViewController)

        // add a pan gesture recognizer to the current place card
        addGestureRecognizers(toViewController: currentCardViewController)


        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardViewController.place) {
            previousCardViewController = dequeuePlaceCardViewController(forPlace: previousPlace)
            scrollView.addSubview(previousCardViewController!.cardView)
            previousCardViewTrailingConstraint = previousCardViewController!.cardView.trailingAnchor.constraint(equalTo: currentCardViewController.cardView.leadingAnchor, constant: -cardViewSpacingConstant)
            constraints += [previousCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                            previousCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidthConstant),
                            previousCardViewTrailingConstraint!]
        }

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardViewController.place) {
            nextCardViewController = dequeuePlaceCardViewController(forPlace: nextPlace)
            scrollView.addSubview(nextCardViewController!.cardView)
            nextCardViewLeadingConstraint = nextCardViewController!.cardView.leadingAnchor.constraint(equalTo: currentCardViewController.cardView.trailingAnchor, constant: cardViewSpacingConstant)
            constraints += [nextCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                            nextCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidthConstant),
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

    func addGestureRecognizers(toViewController viewController: PlaceDetailsCardViewController) {
        viewController.cardView.addGestureRecognizer(panGestureRecognizer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func dequeuePlaceCardViewController(forPlace place: Place) -> PlaceDetailsCardViewController {
        if let placeCardVC = unusedPlaceCardViewControllers.last {
            unusedPlaceCardViewControllers.removeLast()
            placeCardVC.place = place
            return placeCardVC
        }

        let newController = PlaceDetailsCardViewController(place: place)
        newController.placeImageDelegate = self
        newController.cardView.delegate = self
        newController.locationProvider = locationProvider
        return newController
    }

    func didPan(gestureRecognizer: UIPanGestureRecognizer) {

        defer {
            if gestureRecognizer.state == .ended {
                panDirection = .none
            }
        }

        let translationInScrollView = gestureRecognizer.translation(in: self.scrollView)

        if gestureRecognizer.state == .began {
            startConstant = currentCardViewCenterXConstraint?.constant ?? 0

            // detect whether we are scrolling up & down, or left to right.
            // if scrolling up and down, simply set content offset for scrollview
            // otherwise pan and page
            if scrollView.contentSize.height > view.bounds.height
                && abs(translationInScrollView.y) > abs(translationInScrollView.x) {
                panDirection = .vertical
            } else {
                panDirection = .horizontal
            }
        }
        switch panDirection {
        case .horizontal:
            let translationX = gestureRecognizer.translation(in: self.view).x

            if gestureRecognizer.state == .ended {
                // figure out where the view would stop based on the velocity with which the user is panning
                // this is so that paging quickly feels natural
                let velocityX = (0.2 * gestureRecognizer.velocity(in: self.view).x)
                let finalX = startConstant + translationX + velocityX;
                let animationDuration = 0.5

                if canPageToNextPlaceCard(finalXPosition: finalX) {
                    pageToNextPlaceCard(animateWithDuration: animationDuration)
                } else if canPageToPreviousPlaceCard(finalXPosition: finalX) {
                    pageToPreviousPlaceCard(animateWithDuration: animationDuration)
                } else {
                    unwindToCurrentPlaceCard(animateWithDuration: animationDuration)
                }
            } else {
                currentCardViewCenterXConstraint?.constant = startConstant + translationX
            }
        default:
            return
        }

    }

    fileprivate func canPageToNextPlaceCard(finalXPosition: CGFloat) -> Bool {
        return finalXPosition < -(self.view.frame.width * 0.5) && self.nextCardViewController != nil
    }

    fileprivate func pageToNextPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        guard let nextCardViewController = nextCardViewController  else {
            return
        }
        // check to see if there is a next card to the next card
        // add a new view controller to next card view controller
        // if so, remove currentCardViewController centerX constraint
        // add center x constraint to nextCardViewController
        
        let nextCardImageCarousel = addImageCarousel(forNextCard: nextCardViewController)

        previousCardViewController?.cardView.isHidden = true

        let newNextCardViewController = insertNewCardViewController(forPlace: dataSource?.nextPlace(forPlace: nextCardViewController.place))
        let springDamping:CGFloat = newNextCardViewController == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: currentCardViewController, newCurrentCard: nextCardViewController, newNextCard: newNextCardViewController)

        view.layoutIfNeeded()

        // setup constraints for new central card
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = nextCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([self.currentCardViewCenterXConstraint!])

        // animate the constraint changes
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            nextCardImageCarousel.alpha = 1
            self.setBackgroundImage(toPhotoAtURL: nextCardViewController.place.photoURLs?.first)
            self.view.layoutIfNeeded()
        }, completion: { finished in
            if finished {
                // ensure that the correct current, previous and next view controller references are set
                self.imageCarousel.removeFromSuperview()
                self.imageCarousel = nextCardImageCarousel
                self.currentCardViewController.cardView.removeGestureRecognizer(self.panGestureRecognizer)
                if let previousCardViewController = self.previousCardViewController {
                    previousCardViewController.cardView.removeFromSuperview()
                    previousCardViewController.cardView.isHidden = false
                    previousCardViewController.removeFromParentViewController()
                    self.unusedPlaceCardViewControllers.append(previousCardViewController)
                }
                self.previousCardViewController = self.currentCardViewController
                self.currentCardViewController = nextCardViewController
                self.nextCardViewController = newNextCardViewController
                self.placeDetailsCardView(cardView: self.currentCardViewController.cardView, heightDidChange: self.currentCardViewController.cardView.frame.height)
            }
        })
    }

    fileprivate func canPageToPreviousPlaceCard(finalXPosition: CGFloat) -> Bool {
        return finalXPosition > (self.view.frame.width * 0.5) && self.previousCardViewController != nil
    }

    // check to see if there is a previous card to the previous card
    // add a new view controller to previous card view controller
    // if so, remove currentCardViewController centerX constraint
    // add center x constraint to previousCardViewController
    fileprivate func pageToPreviousPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        guard let previousCardViewController = previousCardViewController else {
            return
        }

        // add the image carousel for the previous place card underneath the existing carousel
        // we need to ensure these constraints are applied and rendered before we animate the rest, otherwise we end
        // up with a very odd looking fade transition
        let previousCardImageCarousel = addImageCarousel(forNextCard: previousCardViewController)

        nextCardViewController?.cardView.isHidden = true

        let newPreviousCardViewController = insertNewCardViewController(forPlace: dataSource?.previousPlace(forPlace: previousCardViewController.place))
        let springDamping:CGFloat = newPreviousCardViewController == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: newPreviousCardViewController, newCurrentCard: previousCardViewController, newNextCard: currentCardViewController)

        view.layoutIfNeeded()

        // deactivate and remove current view controller center constraint
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = previousCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([currentCardViewCenterXConstraint!])


        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            previousCardImageCarousel.alpha = 1
            self.setBackgroundImage(toPhotoAtURL: previousCardViewController.place.photoURLs?.first)
            self.view.layoutIfNeeded()
        }, completion: { finished in
            if finished {
                self.currentCardViewController.cardView.removeGestureRecognizer(self.panGestureRecognizer)
                if let nextCardViewController = self.nextCardViewController {
                    nextCardViewController.cardView.removeFromSuperview()
                    nextCardViewController.cardView.isHidden = false
                    nextCardViewController.removeFromParentViewController()
                    self.unusedPlaceCardViewControllers.append(nextCardViewController)
                }
                self.imageCarousel.removeFromSuperview()
                self.imageCarousel = previousCardImageCarousel
                self.nextCardViewController = self.currentCardViewController
                self.currentCardViewController = previousCardViewController
                self.previousCardViewController = newPreviousCardViewController
                self.placeDetailsCardView(cardView: self.currentCardViewController.cardView, heightDidChange: self.currentCardViewController.cardView.frame.height)
            }
        })
    }

    fileprivate func insertNewCardViewController(forPlace place: Place?) -> PlaceDetailsCardViewController? {
        guard let newPlace = place else {
            return nil
        }

        let newCardViewController = dequeuePlaceCardViewController(forPlace:newPlace)
        self.scrollView.addSubview(newCardViewController.cardView)
        self.addChildViewController(newCardViewController)
        NSLayoutConstraint.activate([newCardViewController.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                                     newCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidthConstant)], translatesAutoresizingMaskIntoConstraints: false)

        return newCardViewController
    }

    fileprivate func setupConstraints(forNewPreviousCard newPreviousCard: PlaceDetailsCardViewController?, newCurrentCard: PlaceDetailsCardViewController, newNextCard: PlaceDetailsCardViewController?) {
        var constraintsToDeactivate = [NSLayoutConstraint]()
        var constraintsToActivate = [NSLayoutConstraint]()

        if let previousCardViewTrailingConstraint = previousCardViewTrailingConstraint {
            constraintsToDeactivate += [previousCardViewTrailingConstraint]
        }
        if let previousCard = newPreviousCard {
            self.previousCardViewTrailingConstraint = previousCard.cardView.trailingAnchor.constraint(equalTo: newCurrentCard.cardView.leadingAnchor, constant: -cardViewSpacingConstant)
            constraintsToActivate += [self.previousCardViewTrailingConstraint!]
        } else {
            previousCardViewTrailingConstraint = nil
        }

        if let nextCardViewLeadingConstraint = nextCardViewLeadingConstraint {
            constraintsToDeactivate += [nextCardViewLeadingConstraint]
        }
        if let nextCard = newNextCard {
            self.nextCardViewLeadingConstraint = nextCard.cardView.leadingAnchor.constraint(equalTo: newCurrentCard.cardView.trailingAnchor, constant: cardViewSpacingConstant)
            constraintsToActivate += [self.nextCardViewLeadingConstraint!]
        } else {
            nextCardViewLeadingConstraint = nil
        }

        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        NSLayoutConstraint.activate(constraintsToActivate, translatesAutoresizingMaskIntoConstraints: false)

        self.addGestureRecognizers(toViewController: newCurrentCard)
    }

    fileprivate func unwindToCurrentPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        currentCardViewCenterXConstraint?.constant = 0
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil )
    }

    fileprivate func addImageCarousel(forNextCard nextCard: PlaceDetailsCardViewController) -> UIView {
        // add the image carousel for the next place card underneath the existing carousel
        // we need to ensure these constraints are applied and rendered before we animate the rest, otherwise we end
        // up with a very odd looking fade transition
        let nextCardImageCarousel = nextCard.imageCarousel
        scrollView.insertSubview(nextCardImageCarousel, belowSubview: imageCarousel)
        NSLayoutConstraint.activate([nextCardImageCarousel.topAnchor.constraint(equalTo: scrollView.topAnchor),
                                     nextCardImageCarousel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                                     nextCardImageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     nextCardImageCarousel.heightAnchor.constraint(equalToConstant: imageCarouselHeightConstant)], translatesAutoresizingMaskIntoConstraints: false)

        return nextCardImageCarousel
    }

    func close() {
        self.dismiss(animated: true, completion: nil)

    }

}

extension PlaceDetailViewController: PlaceDetailsImageDelegate {
    func imageCarousel(imageCarousel: UIView, placeImageDidChange newImageURL: URL) {
        if imageCarousel == self.imageCarousel {
            self.backgroundImage.setImageWith(newImageURL)
        }
    }

}

extension PlaceDetailViewController: PlaceDetailsCardDelegate {
    func placeDetailsCardView(cardView: PlaceDetailsCardView, heightDidChange newHeight: CGFloat) {
        guard cardView == currentCardViewController.cardView else {
            return
        }
        let totalViewHeight = newHeight + cardViewTopAnchorConstant
        scrollView.contentSize = CGSize(width: 1, height: totalViewHeight)
        backgroundImageHeightConstraint?.constant = totalViewHeight
        self.updateViewConstraints()
        if totalViewHeight > view.bounds.height {
            scrollView.isScrollEnabled = true
        } else {
            scrollView.isScrollEnabled = false
        }
    }
}
extension PlaceDetailViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == scrollView.panGestureRecognizer
    }
}
