/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking

private let cardBottomMargin: CGFloat = 10 // eyeballed. Sorry antlam.

// MARK: Animation Constants
fileprivate let cardFadeOutAlpha: CGFloat = 0.6
private let spacing: CGFloat = 10

// Transforms for card swipe animation
fileprivate let scaleOutTransformLeft = CGAffineTransform.identity.translatedBy(x: 3, y: 10).scaledBy(x: 0.96, y: 0.96)
fileprivate let scaleOutTransformRight = CGAffineTransform.identity.translatedBy(x: -3, y: 10).scaledBy(x: 0.96, y: 0.96)

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

    weak var dataSource: PlacesProvider?

    weak var locationProvider: LocationProvider? {
        didSet {
            self.currentCardViewController.locationProvider = locationProvider
        }
    }

    fileprivate lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(gestureRecognizer:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        return panGesture
    }()
    
    lazy var mapButton: UIButton = {
        let button = UIButton()
        button.setImage(#imageLiteral(resourceName: "button_map"), for: .normal)
        button.addTarget(self, action: #selector(self.openMapView), for: .touchUpInside)
        return button
    }()

    lazy var filterButton: UIButton = {
        let button = UIButton()
        button.setImage(#imageLiteral(resourceName: "button_filter"), for: .normal)
        button.addTarget(self, action: #selector(didPressFilter), for: .touchUpInside)
        return button
    }()

    fileprivate var previousCardViewController: PlaceDetailsCardViewController?
    fileprivate var currentCardViewController: PlaceDetailsCardViewController! {
        didSet {
            updateCurrentCardConstraints()
        }
    }
    fileprivate var nextCardViewController: PlaceDetailsCardViewController?

    fileprivate var currentCardViewCenterXConstraint: NSLayoutConstraint?
    fileprivate var previousCardViewTrailingConstraint: NSLayoutConstraint?
    fileprivate var nextCardViewLeadingConstraint: NSLayoutConstraint?
    fileprivate var filterShowConstraints = [NSLayoutConstraint]()
    fileprivate var filterHideConstraints = [NSLayoutConstraint]()

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
    fileprivate let cardSlideDuration: TimeInterval = 0.15

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

    fileprivate func setBackgroundImage(toPhotoAtURL photoURL: URL?) {
        let placeholder = UIImage(named: "place-placeholder")
        if let imageURL = photoURL {
            let imageRequest = URLRequest(url: imageURL)
            let cachedImage = UIImageView.sharedImageDownloader().imageCache?.imageforRequest(imageRequest, withAdditionalIdentifier: nil)

            // Perform a cross fade between the existing/new images
            let crossFade = CABasicAnimation(keyPath: "contents")
            crossFade.duration = 0.4
            crossFade.fromValue = backgroundImage.image?.cgImage
            crossFade.toValue = cachedImage ?? placeholder
            backgroundImage.layer.add(crossFade, forKey: "animateContents")

            self.backgroundImage.setImageWith(imageURL, placeholderImage: placeholder)
        } else {
            backgroundImage.image = placeholder
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        cardViewWidth = self.view.bounds.width - (2 * cardEdgeMarginConstant)

        // Add some additional height to the background image so when the spring animation runs when
        // transitioning to the this VC we don't see a blank space poke through the bottom due to the spring
        let springOverlap: CGFloat = 5

        imageCarousel = currentCardViewController.imageCarousel
        view.addSubview(backgroundImage)
        view.addSubview(imageCarousel)

        backgroundImage.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
            make.topMargin.equalTo(imageCarouselHeightConstant - springOverlap)
        }

        backgroundImage.addSubview(backgroundBlurEffect)
        var constraints = [backgroundBlurEffect.topAnchor.constraint(equalTo: backgroundImage.topAnchor),
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

        constraints += [imageCarousel.topAnchor.constraint(equalTo: view.topAnchor),
                           imageCarousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           imageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           imageCarousel.heightAnchor.constraint(equalToConstant: imageCarouselHeightConstant)]

        view.addSubview(currentCardViewController.cardView)

        updateCurrentCardConstraints()
        currentCardViewCenterXConstraint = currentCardViewController.cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        constraints += filterHideConstraints
        constraints += [currentCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                        currentCardViewCenterXConstraint!]
        self.addChildViewController(currentCardViewController)

        // add a pan gesture recognizer to the current place card
        addGestureRecognizers(toViewController: currentCardViewController)


        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardViewController.place) {
            initCardViewController(forPrevious: previousPlace)
        }

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardViewController.place) {
            initCardViewController(forNext: nextPlace)
        }

        view.addSubview(mapButton)
        constraints += [mapButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
                        mapButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: spacing),
                        mapButton.heightAnchor.constraint(equalToConstant: 48),
                        mapButton.widthAnchor.constraint(equalToConstant: 48)]

        view.addSubview(filterButton)
        constraints += [filterButton.centerYAnchor.constraint(equalTo: mapButton.centerYAnchor),
                        filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -spacing),
                        filterButton.heightAnchor.constraint(equalToConstant: 48),
                        filterButton.widthAnchor.constraint(equalToConstant: 48)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func initCardViewController(forPrevious place: Place) {
        // Constraint duplication with insertNewCardViewController, updateCurrentCardConstraints & initCardViewController(forNext:). See usages of -cardBottomMargin.
        previousCardViewController = dequeuePlaceCardViewController(forPlace: place)
        previousCardViewController?.cardView.transform = scaleOutTransformLeft
        view.addSubview(previousCardViewController!.cardView)
        previousCardViewTrailingConstraint = previousCardViewController!.cardView.trailingAnchor.constraint(equalTo: currentCardViewController.cardView.leadingAnchor, constant: -cardViewSpacingConstant)
        let constraints = [
            previousCardViewController!.cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: cardViewTopAnchorConstant),
            previousCardViewController!.cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -cardBottomMargin),
            previousCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
            previousCardViewTrailingConstraint!
        ]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func initCardViewController(forNext place: Place) {
        // Constraint duplication with insertNewCardViewController, updateCurrentCardConstraints & initCardViewController(forPrevious:). See usages of -cardBottomMargin.
        nextCardViewController = dequeuePlaceCardViewController(forPlace: place)
        nextCardViewController?.cardView.transform = scaleOutTransformRight
        view.addSubview(nextCardViewController!.cardView)
        nextCardViewLeadingConstraint = nextCardViewController!.cardView.leadingAnchor.constraint(equalTo: currentCardViewController.cardView.trailingAnchor, constant: cardViewSpacingConstant)
        let constraints = [
            nextCardViewController!.cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: cardViewTopAnchorConstant),
            nextCardViewController!.cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -cardBottomMargin),
            nextCardViewController!.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
            nextCardViewLeadingConstraint!
        ]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func updateCurrentCardConstraints() {
        // Constraint duplication with insertNewCardViewController & initCardViewController(*. See usages of -cardBottomMargin.
        filterShowConstraints = [ currentCardViewController.cardView.topAnchor.constraint(equalTo: view.bottomAnchor) ]
        filterHideConstraints = [
            currentCardViewController.cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: cardViewTopAnchorConstant),
            currentCardViewController.cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -cardBottomMargin),
        ]
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

    /// Opens the existing place card without animation.
    func openCard(forExistingPlace placeToOpen: Place) {
        guard let dataSource = dataSource,
                let index = dataSource.index(forPlace: placeToOpen) else {
            log.error("Unable to find place \(placeToOpen.id) in data source. Cannot open card.")
            return
        }

        // The VCs in this class handle like a linked list so we can just update the prev, middle,
        // and next nodes, and the view will continue working as usual.
        currentCardViewController.place = placeToOpen

        let nextIndex = index + 1
        if nextIndex >= dataSource.numberOfPlaces() {
            removeCardViewController(nextCardViewController)
            nextCardViewController = nil
        } else if let nextPlace = try? dataSource.place(forIndex: nextIndex) {
            if let nextVC = nextCardViewController {
                nextVC.place = nextPlace
            } else {
                initCardViewController(forNext: nextPlace)
            }
        }

        let previousIndex = index - 1
        if previousIndex < 0 {
            removeCardViewController(previousCardViewController)
            previousCardViewController = nil
        } else if let previousPlace = try? dataSource.place(forIndex: previousIndex) {
            if let prevVC = previousCardViewController {
                prevVC.place = previousPlace
            } else {
                initCardViewController(forPrevious: previousPlace)
            }
        }
    }

    /// Removes the given VC from the view hierarchy if it exists, else no-op.
    private func removeCardViewController(_ controller: PlaceDetailsCardViewController?) {
        guard let controller = controller else { return }
        controller.cardView.removeFromSuperview()
        controller.cardView.isHidden = false
        controller.removeFromParentViewController()
    }

    fileprivate func dequeuePlaceCardViewController(forPlace place: Place) -> PlaceDetailsCardViewController {
        let newController = PlaceDetailsCardViewController(place: place)
        newController.placeImageDelegate = self
        newController.locationProvider = locationProvider
        newController.cardView.alpha = cardFadeOutAlpha
        return newController
    }

    @objc fileprivate func didPan(gestureRecognizer: UIPanGestureRecognizer) {
        let translationX = gestureRecognizer.translation(in: self.view).x

        if gestureRecognizer.state == .ended {
            // figure out where the view would stop based on the velocity with which the user is panning
            // this is so that paging quickly feels natural
            let velocityX = (0.2 * gestureRecognizer.velocity(in: self.view).x)
            let finalX = translationX + velocityX;
            let animationDuration = 0.5

            if canPageToNextPlaceCard(finalXPosition: finalX) {
                pageToNextPlaceCard(animateWithDuration: animationDuration)
            } else if canPageToPreviousPlaceCard(finalXPosition: finalX) {
                pageToPreviousPlaceCard(animateWithDuration: animationDuration)
            } else {
                unwindToCurrentPlaceCard(animateWithDuration: animationDuration)
            }
        } else {
            currentCardViewCenterXConstraint?.constant = translationX

            let currentCenter = currentCardViewController.cardView.center
            currentCardViewController.cardView.alpha = calculateAlpha(forCenterPosition: currentCenter)

            if let nextCenter = nextCardViewController?.cardView.center {
                nextCardViewController?.cardView.alpha = calculateAlpha(forCenterPosition: nextCenter)
            }

            if let prevCenter = previousCardViewController?.cardView.center {
                previousCardViewController?.cardView.alpha = calculateAlpha(forCenterPosition: prevCenter)
            }
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
                self.removeCardViewController(self.previousCardViewController)
                self.previousCardViewController = self.currentCardViewController
                self.currentCardViewController = nextCardViewController
                self.nextCardViewController = newNextCardViewController

                self.currentCardViewController.beginAutoMovingOfCarousel()

                let cardPos = self.dataSource?.index(forPlace: self.currentCardViewController.place) ?? -1
                AppState.trackCardVisit(cardPos: cardPos)
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
                self.removeCardViewController(self.nextCardViewController)
                self.imageCarousel.removeFromSuperview()
                self.imageCarousel = previousCardImageCarousel
                self.nextCardViewController = self.currentCardViewController
                self.currentCardViewController = previousCardViewController
                self.previousCardViewController = newPreviousCardViewController

                self.currentCardViewController.beginAutoMovingOfCarousel()
                let cardPos = self.dataSource?.index(forPlace: self.currentCardViewController.place) ?? -1
                AppState.trackCardVisit(cardPos: cardPos)
            }
        })
    }

    fileprivate func insertNewCardViewController(forPlace place: Place?) -> PlaceDetailsCardViewController? {
        guard let newPlace = place else {
            return nil
        }

        let newCardViewController = dequeuePlaceCardViewController(forPlace:newPlace)
        self.view.addSubview(newCardViewController.cardView)
        self.addChildViewController(newCardViewController)
        // Constraint duplication with updateCurrentCardConstraints & initCardViewController(*. See usages of -cardBottomMargin.
        NSLayoutConstraint.activate([
            newCardViewController.cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: cardViewTopAnchorConstant),
            newCardViewController.cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -cardBottomMargin),
            newCardViewController.cardView.widthAnchor.constraint(equalToConstant: cardViewWidth)
            ], translatesAutoresizingMaskIntoConstraints: false)
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
        view.insertSubview(nextCardImageCarousel, belowSubview: imageCarousel)
        NSLayoutConstraint.activate([nextCardImageCarousel.topAnchor.constraint(equalTo: view.topAnchor),
                                     nextCardImageCarousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     nextCardImageCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     nextCardImageCarousel.heightAnchor.constraint(equalToConstant: imageCarouselHeightConstant)], translatesAutoresizingMaskIntoConstraints: false)

        return nextCardImageCarousel
    }

    @objc private func openMapView() {
        let controller = MapViewController()
        controller.delegate = self
        controller.placesProvider = dataSource
        controller.locationProvider = locationProvider
        self.present(controller, animated: true)
    }

    @objc private func didPressFilter() {
        guard let dataSource = dataSource else { return }

        let filterVC = FilterViewController(enabledFilters: dataSource.enabledFilters, topRatedOnly: dataSource.topRatedOnly)
        filterVC.delegate = self
        filterVC.placeCount = dataSource.numberOfPlaces()
        present(filterVC, animated: true, completion: nil)

        slideCurrentCardView(willBeShown: false)
    }

    fileprivate func slideCurrentCardView(willBeShown: Bool) {
        UIView.animate(withDuration: cardSlideDuration) {
            if willBeShown {
                NSLayoutConstraint.deactivate(self.filterShowConstraints)
                NSLayoutConstraint.activate(self.filterHideConstraints)
            } else {
                NSLayoutConstraint.deactivate(self.filterHideConstraints)
                NSLayoutConstraint.activate(self.filterShowConstraints)
            }
            self.view.layoutIfNeeded()
        }
    }
}

extension PlaceDetailViewController: PlaceDetailsImageDelegate {
    func imageCarousel(imageCarousel: UIView, placeImageDidChange newImageURL: URL) {
        if imageCarousel == self.imageCarousel {
            setBackgroundImage(toPhotoAtURL: newImageURL)
        }
    }

}

extension PlaceDetailViewController: FilterViewControllerDelegate {
    func filterViewController(_ filterViewController: FilterViewController, didUpdateFilters enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        guard let count = dataSource?.filterPlaces(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly).count else { return }
        filterViewController.placeCount = count
    }

    func filterViewController(_ filterViewController: FilterViewController, didDismissWithFilters enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        guard let dataSource = dataSource else { return }
        dataSource.refresh(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)

        slideCurrentCardView(willBeShown: true)
    }
}

extension PlaceDetailViewController: MapViewControllerDelegate {
    func mapViewController(didSelect selectedPlace: Place) {
        openCard(forExistingPlace: selectedPlace)
    }
}
