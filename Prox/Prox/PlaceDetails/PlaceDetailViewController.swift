/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking
import BadgeSwift

enum PanDirection {
    case vertical, horizontal, none
}

struct PlaceDetailAnimatableViews {
    var nextCard: PlaceDetailsCardView?
    var previousCard: PlaceDetailsCardView?
    var mapButton: MapButton
    var currentCard: PlaceDetailsCardView
    var mapButtonBadge: BadgeSwift
    var backgroundImage: UIImageView
}

// MARK: Animation Constants
fileprivate let cardFadeOutAlpha: CGFloat = 0.6

// Transforms for card swipe animation
fileprivate let scaleOutTransformLeft = CGAffineTransform.identity.translatedBy(x: 3, y: 20).scaledBy(x: 0.96, y: 0.96)
fileprivate let scaleOutTransformRight = CGAffineTransform.identity.translatedBy(x: -3, y: 20).scaledBy(x: 0.96, y: 0.96)

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

    var currentPlace: Place {
        return currentCardViewController.place
    }

    fileprivate let cardViewTopAnchorConstant: CGFloat = 204
    fileprivate let cardViewSpacingConstant: CGFloat = 6
    fileprivate let cardEdgeMarginConstant:CGFloat = 16
    fileprivate var cardViewWidth: CGFloat = 0
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

    lazy var backgroundGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [Colors.detailsViewBackgroundGradientStart.cgColor,
                        Colors.detailsViewBackgroundGradientEnd.cgColor]
        return layer
    }()

    fileprivate var panDirection: PanDirection = .none

    init(place: Place) {
        super.init(nibName: nil, bundle: nil)

        AppState.enterDetails()
        let index = dataSource != nil ? dataSource!.index(forPlace: place) ?? 0 : 0
        AppState.trackCardVisit(cardPos: index)

        self.currentCardViewController = dequeuePlaceCardViewController(forPlace: place)
        self.currentCardViewController.cardView.alpha = 1
        self.currentCardViewController.cardView.transform = .identity
        setBackgroundImage(toPhotoAtURL: place.photoURLs.first)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func placesUpdated() {
        mapButtonBadge.text = "\(dataSource?.numberOfPlaces() ?? 0)"

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardViewController.place) {
            if let nextCardViewController = nextCardViewController {
                nextCardViewController.place = nextPlace
            } else {
                nextCardViewController = dequeuePlaceCardViewController(forPlace: nextPlace)
                nextCardViewController?.cardView.transform = scaleOutTransformRight
                scrollView.addSubview(nextCardViewController!.cardView)
                nextCardViewLeadingConstraint = nextCardViewController!.cardView.leadingAnchor.constraint(equalTo: currentCardViewController.cardView.trailingAnchor, constant: cardViewSpacingConstant)
                NSLayoutConstraint.activate( [nextCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                                nextCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                                nextCardViewLeadingConstraint!], translatesAutoresizingMaskIntoConstraints: false)
            }
        } else {
            nextCardViewController?.cardView.removeFromSuperview()
            nextCardViewController?.removeFromParentViewController()
        }

        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardViewController.place) {
            if let previousCardViewController = previousCardViewController {
                previousCardViewController.place = previousPlace
            } else  {
                previousCardViewController = dequeuePlaceCardViewController(forPlace: previousPlace)
                previousCardViewController?.cardView.transform = scaleOutTransformLeft
                scrollView.addSubview(previousCardViewController!.cardView)
                previousCardViewTrailingConstraint = previousCardViewController!.cardView.trailingAnchor.constraint(equalTo: currentCardViewController.cardView.leadingAnchor, constant: -cardViewSpacingConstant)
                NSLayoutConstraint.activate( [previousCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                                previousCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                                previousCardViewTrailingConstraint!], translatesAutoresizingMaskIntoConstraints: false)
            }
        } else {
            previousCardViewController?.cardView.removeFromSuperview()
            previousCardViewController?.removeFromParentViewController()
        }

        view.setNeedsLayout()
    }

    fileprivate func setBackgroundImage(toPhotoAtURL photoURLString: String?) {
        if let imageURLString = photoURLString,
            let imageURL = URL(string: imageURLString) {

            let imageRequest = URLRequest(url: imageURL)
            let cachedImage = UIImageView.sharedImageDownloader().imageCache?.imageforRequest(imageRequest, withAdditionalIdentifier: nil)

            // Perform a cross fade between the existing/new images
            let crossFade = CABasicAnimation(keyPath: "contents")
            crossFade.duration = 0.4
            crossFade.fromValue = backgroundImage.image?.cgImage
            crossFade.toValue = cachedImage
            backgroundImage.layer.add(crossFade, forKey: "animateContents")

            self.backgroundImage.setImageWith(imageURL)
        } else {
            backgroundImage.image = UIImage(named: "place-placeholder")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        cardViewWidth = self.view.bounds.width - (2 * cardEdgeMarginConstant)

        // Add some additional height to the background image so when the spring animation runs when
        // transitioning to the this VC we don't see a blank space poke through the bottom due to the spring
        let springOverlap: CGFloat = 5
        
        view.addSubview(scrollView)
        var constraints = [scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                           scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        imageCarousel = currentCardViewController.imageCarousel
        scrollView.addSubview(backgroundImage)
        scrollView.addSubview(imageCarousel)

        backgroundImageHeightConstraint = backgroundImage.heightAnchor.constraint(equalToConstant: scrollView.contentSize.height)

        constraints += [backgroundImage.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: imageCarouselHeightConstant - springOverlap),
                           backgroundImage.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                           backgroundImageHeightConstraint!,
                           backgroundImage.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        backgroundImage.addSubview(backgroundBlurEffect)
        constraints += [backgroundBlurEffect.topAnchor.constraint(equalTo: backgroundImage.topAnchor),
                       backgroundBlurEffect.leadingAnchor.constraint(equalTo: backgroundImage.leadingAnchor),
                       backgroundBlurEffect.bottomAnchor.constraint(equalTo: backgroundImage.bottomAnchor),
                       backgroundBlurEffect.trailingAnchor.constraint(equalTo: backgroundImage.trailingAnchor)]

        // Using a separate gradient view allows us to apply the gradient after blur (as opposed to
        // using a layer of the BG image or BlurEffect, which would apply it before the blur).
        let gradientView = UIView()
        gradientView.layer.addSublayer(backgroundGradientLayer)
        backgroundImage.addSubview(gradientView)
        constraints += [gradientView.topAnchor.constraint(equalTo: backgroundImage.topAnchor),
                        gradientView.leadingAnchor.constraint(equalTo: backgroundImage.leadingAnchor),
                        gradientView.bottomAnchor.constraint(equalTo: backgroundImage.bottomAnchor),
                        gradientView.trailingAnchor.constraint(equalTo: backgroundImage.trailingAnchor)]

        constraints += [imageCarousel.topAnchor.constraint(equalTo: scrollView.topAnchor),
                           imageCarousel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                           imageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           imageCarousel.heightAnchor.constraint(equalToConstant: imageCarouselHeightConstant)]

        scrollView.addSubview(currentCardViewController.cardView)
        currentCardViewCenterXConstraint = currentCardViewController.cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        constraints += [currentCardViewController.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                        currentCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                        currentCardViewCenterXConstraint!]
        self.addChildViewController(currentCardViewController)

        // add a pan gesture recognizer to the current place card
        addGestureRecognizers(toViewController: currentCardViewController)


        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardViewController.place) {
            previousCardViewController = dequeuePlaceCardViewController(forPlace: previousPlace)
            previousCardViewController?.cardView.transform = scaleOutTransformLeft
            scrollView.addSubview(previousCardViewController!.cardView)
            previousCardViewTrailingConstraint = previousCardViewController!.cardView.trailingAnchor.constraint(equalTo: currentCardViewController.cardView.leadingAnchor, constant: -cardViewSpacingConstant)
            constraints += [previousCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                            previousCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                            previousCardViewTrailingConstraint!]
        }

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardViewController.place) {
            nextCardViewController = dequeuePlaceCardViewController(forPlace: nextPlace)
            nextCardViewController?.cardView.transform = scaleOutTransformRight
            scrollView.addSubview(nextCardViewController!.cardView)
            nextCardViewLeadingConstraint = nextCardViewController!.cardView.leadingAnchor.constraint(equalTo: currentCardViewController.cardView.trailingAnchor, constant: cardViewSpacingConstant)
            constraints += [nextCardViewController!.cardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                            nextCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = backgroundImage.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.currentCardViewController.beginAutoMovingOfCarousel()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func addGestureRecognizers(toViewController viewController: PlaceDetailsCardViewController) {
        viewController.cardView.addGestureRecognizer(panGestureRecognizer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func openCard(forPlaceWithEvent placeWithEvent: Place) {
        if currentCardViewController.place == placeWithEvent {
            currentCardViewController.place.events = placeWithEvent.events
            // if we're currently looking at that card then just animate in the event
            currentCardViewController.showEvent()
        } else {
            // Page to new card.
            pageForwardToCard(forPlace: placeWithEvent)
        }
    }

    fileprivate func pageForwardToCard(forPlace place: Place) {
        guard let newCurrentViewController = insertNewCardViewController(forPlace: place) else { return }

        // check to see if there is a next card to the next card
        // add a new view controller to next card view controller
        // if so, remove currentCardViewController centerX constraint
        // add center x constraint to nextCardViewController
        
        let nextCardImageCarousel = addImageCarousel(forNextCard: newCurrentViewController)

        previousCardViewController?.cardView.isHidden = true

        let newNextCardViewController = insertNewCardViewController(forPlace: dataSource?.nextPlace(forPlace: place))

        let newPreviousCardViewController = insertNewCardViewController(forPlace: dataSource?.previousPlace(forPlace: place))

        let springDamping:CGFloat = newNextCardViewController == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: newPreviousCardViewController, newCurrentCard: newCurrentViewController, newNextCard: newNextCardViewController)

        view.layoutIfNeeded()

        // setup constraints for new central card
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = newCurrentViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([self.currentCardViewCenterXConstraint!])

        // animate the constraint changes
        UIView.animate(withDuration: 0.1, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            nextCardImageCarousel.alpha = 1
            self.setBackgroundImage(toPhotoAtURL: newCurrentViewController.place.photoURLs.first)
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
                if let nextCardViewController = self.nextCardViewController {
                    nextCardViewController.cardView.removeFromSuperview()
                    nextCardViewController.cardView.isHidden = false
                    nextCardViewController.removeFromParentViewController()
                    self.unusedPlaceCardViewControllers.append(nextCardViewController)
                }
                self.currentCardViewController.cardView.removeFromSuperview()
                self.currentCardViewController.cardView.isHidden = false
                self.currentCardViewController.removeFromParentViewController()
                self.unusedPlaceCardViewControllers.append(self.currentCardViewController)

                self.previousCardViewController = newPreviousCardViewController
                self.currentCardViewController = newCurrentViewController
                self.nextCardViewController = newNextCardViewController
                self.placeDetailsCardView(cardView: self.currentCardViewController.cardView, heightDidChange: self.currentCardViewController.cardView.frame.height)
            }
        })
    }

    fileprivate func dequeuePlaceCardViewController(forPlace place: Place) -> PlaceDetailsCardViewController {
        guard let placeCardVC = unusedPlaceCardViewControllers.last else {
            let newController = PlaceDetailsCardViewController(place: place)
            newController.placeImageDelegate = self
            newController.cardView.delegate = self
            newController.locationProvider = locationProvider
            newController.cardView.alpha = cardFadeOutAlpha
            return newController
        }

        placeCardVC.prepareForReuse()
        unusedPlaceCardViewControllers.removeLast()
        placeCardVC.place = place
        placeCardVC.cardView.alpha = cardFadeOutAlpha
        return placeCardVC
    }

    @objc fileprivate func didPan(gestureRecognizer: UIPanGestureRecognizer) {
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

                let currentCenter = currentCardViewController.cardView.center
                currentCardViewController.cardView.alpha = calculateAlpha(forCenterPosition: currentCenter)

                if let nextCenter = nextCardViewController?.cardView.center {
                    nextCardViewController?.cardView.alpha = calculateAlpha(forCenterPosition: nextCenter)
                }

                if let prevCenter = previousCardViewController?.cardView.center {
                    previousCardViewController?.cardView.alpha = calculateAlpha(forCenterPosition: prevCenter)
                }
            }
        default:
            return
        }

    }

    fileprivate func calculateAlpha(forCenterPosition position: CGPoint) -> CGFloat {
        // Normalize X position to be 0 = center of screen
        let adjustedXPos = position.x - (UIScreen.main.bounds.width / 2)
        return 1 - min(CGFloat((fabsf(Float(adjustedXPos)) /  Float(UIScreen.main.bounds.width / 2)) * Float(0.4)), 0.4)
    }

    fileprivate func canPageToNextPlaceCard(finalXPosition: CGFloat) -> Bool {
        return finalXPosition < -(self.view.frame.width * 0.5) && self.nextCardViewController != nil
    }

    fileprivate func pageToNextPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        guard let nextCardViewController = nextCardViewController  else {
            return
        }

        self.currentCardViewController.stopAutoMovingOfCarousel()
        
        // check to see if there is a next card to the next card
        // add a new view controller to next card view controller
        // if so, remove currentCardViewController centerX constraint
        // add center x constraint to nextCardViewController
        
        let nextCardImageCarousel = addImageCarousel(forNextCard: nextCardViewController)

        previousCardViewController?.cardView.isHidden = true

        let newNextCardViewController = insertNewCardViewController(forPlace: dataSource?.nextPlace(forPlace: nextCardViewController.place))
        newNextCardViewController?.cardView.transform = scaleOutTransformRight

        let springDamping:CGFloat = newNextCardViewController == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: currentCardViewController, newCurrentCard: nextCardViewController, newNextCard: newNextCardViewController)
        AppState.trackCardVisit(cardPos: (dataSource?.index(forPlace: nextCardViewController.place))!)

        view.layoutIfNeeded()

        // setup constraints for new central card
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = nextCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([self.currentCardViewCenterXConstraint!])

        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            nextCardImageCarousel.alpha = 1
            nextCardViewController.cardView.alpha = 1
            self.currentCardViewController.cardView.alpha = cardFadeOutAlpha
            self.setBackgroundImage(toPhotoAtURL: nextCardViewController.place.photoURLs.first)
            self.view.layoutIfNeeded()

            self.nextCardViewController?.cardView.transform = CGAffineTransform.identity
            self.currentCardViewController.cardView.transform = scaleOutTransformLeft
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

                self.currentCardViewController.beginAutoMovingOfCarousel()
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

        self.currentCardViewController.stopAutoMovingOfCarousel()

        // add the image carousel for the previous place card underneath the existing carousel
        // we need to ensure these constraints are applied and rendered before we animate the rest, otherwise we end
        // up with a very odd looking fade transition
        let previousCardImageCarousel = addImageCarousel(forNextCard: previousCardViewController)

        nextCardViewController?.cardView.isHidden = true

        let newPreviousCardViewController = insertNewCardViewController(forPlace: dataSource?.previousPlace(forPlace: previousCardViewController.place))
        newPreviousCardViewController?.cardView.transform = scaleOutTransformLeft

        let springDamping:CGFloat = newPreviousCardViewController == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: newPreviousCardViewController, newCurrentCard: previousCardViewController, newNextCard: currentCardViewController)
        AppState.trackCardVisit(cardPos: (dataSource?.index(forPlace: previousCardViewController.place))!)

        view.layoutIfNeeded()

        // deactivate and remove current view controller center constraint
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = previousCardViewController.cardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([currentCardViewCenterXConstraint!])

        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            previousCardImageCarousel.alpha = 1
            previousCardViewController.cardView.alpha = 1
            self.currentCardViewController.cardView.alpha = cardFadeOutAlpha
            self.setBackgroundImage(toPhotoAtURL: previousCardViewController.place.photoURLs.first)
            self.view.layoutIfNeeded()

            self.previousCardViewController?.cardView.transform = CGAffineTransform.identity
            self.currentCardViewController.cardView.transform = scaleOutTransformRight
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

                self.currentCardViewController.beginAutoMovingOfCarousel()
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
                                     newCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth)], translatesAutoresizingMaskIntoConstraints: false)
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
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.nextCardViewController?.cardView.alpha = cardFadeOutAlpha
            self.previousCardViewController?.cardView.alpha = cardFadeOutAlpha
            self.currentCardViewController?.cardView.alpha = 1.0
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
        Analytics.logEvent(event: AnalyticsEvent.MAP_BUTTON, params: [:])
        AppState.enterCarousel()
        self.dismiss(animated: true, completion: nil)

    }

}

extension PlaceDetailViewController: PlaceDetailsImageDelegate {
    func imageCarousel(imageCarousel: UIView, placeImageDidChange newImageURL: URL) {
        if imageCarousel == self.imageCarousel {
            setBackgroundImage(toPhotoAtURL: newImageURL.absoluteString)
        }
    }

}

extension PlaceDetailViewController: PlaceDetailsCardDelegate {
    func placeDetailsCardView(cardView: PlaceDetailsCardView, heightDidChange newHeight: CGFloat) {
        guard cardView == currentCardViewController.cardView else {
            return
        }
        let totalViewHeight = newHeight + cardViewTopAnchorConstant + 25
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

extension PlaceDetailViewController: Animatable {
    func animatableProperties() -> PlaceDetailAnimatableViews {
        return PlaceDetailAnimatableViews(
            nextCard: self.nextCardViewController?.cardView,
            previousCard: self.previousCardViewController?.cardView,
            mapButton: self.mapButton,
            currentCard: self.currentCardViewController.cardView,
            mapButtonBadge: self.mapButtonBadge,
            backgroundImage: self.backgroundImage
        )
    }
}
