/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AFNetworking

enum PanDirection {
    case vertical, horizontal, none
}

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
    let locationProvider: LocationProvider

    lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isScrollEnabled = false
        scrollView.contentSize = CGSize(width: 1, height: self.view.bounds.height)
        scrollView.bounces = false
        return scrollView
    }()

    fileprivate lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didPan(gestureRecognizer:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = self
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

    fileprivate var previousCardView: PlaceDetailsCardView?
    fileprivate var currentCardView: PlaceDetailsCardView! {
        didSet {
            updateCurrentCardConstraints()
        }
    }
    fileprivate var nextCardView: PlaceDetailsCardView?

    fileprivate var currentCardViewCenterXConstraint: NSLayoutConstraint?
    fileprivate var previousCardViewTrailingConstraint: NSLayoutConstraint?
    fileprivate var nextCardViewLeadingConstraint: NSLayoutConstraint?
    fileprivate var backgroundImageHeightConstraint: NSLayoutConstraint?
    fileprivate var filterShowConstraints = [NSLayoutConstraint]()
    fileprivate var filterHideConstraints = [NSLayoutConstraint]()

    var imageCarousel: UIView!

    var currentPlace: Place {
        return currentCardView.place
    }

    fileprivate let cardViewTopAnchorConstant: CGFloat = 204
    fileprivate let cardViewSpacingConstant: CGFloat = 6
    fileprivate let cardEdgeMarginConstant:CGFloat = 16
    fileprivate var cardViewWidth: CGFloat = 0
    fileprivate let imageCarouselHeightConstant: CGFloat = 240
    fileprivate let animationDurationConstant = 0.5
    fileprivate let cardSlideDuration: TimeInterval = 0.15

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

    init(place: Place, locationProvider: LocationProvider) {
        self.locationProvider = locationProvider
        super.init(nibName: nil, bundle: nil)

        AppState.enterDetails()
        let index = dataSource != nil ? dataSource!.index(forPlace: place) ?? 0 : 0
        AppState.trackCardVisit(cardPos: index)

        self.currentCardView = dequeuePlaceCardView(forPlace: place)
        self.currentCardView.alpha = 1
        self.currentCardView.transform = .identity
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
        
        view.addSubview(scrollView)
        var constraints = [scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                           scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        imageCarousel = currentCardView.imageCarousel
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

        scrollView.addSubview(currentCardView)

        updateCurrentCardConstraints()
        currentCardViewCenterXConstraint = currentCardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        constraints += filterHideConstraints
        constraints += [currentCardView.widthAnchor.constraint(equalToConstant: cardViewWidth),
                        currentCardViewCenterXConstraint!]

        // add a pan gesture recognizer to the current place card
        addGestureRecognizers(toView: currentCardView)


        if let previousPlace = dataSource?.previousPlace(forPlace: currentCardView.place) {
            initCardView(forPrevious: previousPlace)
        }

        if let nextPlace = dataSource?.nextPlace(forPlace: currentCardView.place) {
            initCardView(forNext: nextPlace)
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

    private func initCardView(forPrevious place: Place) {
        // Constraint duplication with insertNewCardView, updateCurrentCardConstraints & initCardView(forNext:).
        previousCardView = dequeuePlaceCardView(forPlace: place)
        previousCardView?.transform = scaleOutTransformLeft
        scrollView.addSubview(previousCardView!)
        previousCardViewTrailingConstraint = previousCardView!.trailingAnchor.constraint(equalTo: currentCardView.leadingAnchor, constant: -cardViewSpacingConstant)
        let constraints = [
            previousCardView!.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
            previousCardView!.widthAnchor.constraint(equalToConstant: cardViewWidth),
            previousCardViewTrailingConstraint!
        ]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func initCardView(forNext place: Place) {
        // Constraint duplication with insertNewCardView, updateCurrentCardConstraints & initCardView(forPrevious:).
        nextCardView = dequeuePlaceCardView(forPlace: place)
        nextCardView?.transform = scaleOutTransformRight
        scrollView.addSubview(nextCardView!)
        nextCardViewLeadingConstraint = nextCardView!.leadingAnchor.constraint(equalTo: currentCardView.trailingAnchor, constant: cardViewSpacingConstant)
        let constraints = [
            nextCardView!.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
            nextCardView!.widthAnchor.constraint(equalToConstant: cardViewWidth),
            nextCardViewLeadingConstraint!
        ]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func updateCurrentCardConstraints() {
        // Constraint duplication with insertNewCardView & initCardView(*.
        filterShowConstraints = [ currentCardView.topAnchor.constraint(equalTo: view.bottomAnchor) ]
        filterHideConstraints = [ currentCardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant) ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = backgroundImage.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.currentCardView.imageCarousel.beginAutoMove()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func addGestureRecognizers(toView view: PlaceDetailsCardView) {
        view.addGestureRecognizer(panGestureRecognizer)
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
        let userLocation = locationProvider.getCurrentLocation()
        currentCardView.updateUI(forPlace: placeToOpen, withUserLocation: userLocation)

        let nextIndex = index + 1
        if nextIndex >= dataSource.numberOfPlaces() {
            removeCardView(nextCardView)
            nextCardView = nil
        } else if let nextPlace = try? dataSource.place(forIndex: nextIndex) {
            if let nextVC = nextCardView {
                nextVC.updateUI(forPlace: nextPlace, withUserLocation: userLocation)
            } else {
                initCardView(forNext: nextPlace)
            }
        }

        let previousIndex = index - 1
        if previousIndex < 0 {
            removeCardView(previousCardView)
            previousCardView = nil
        } else if let previousPlace = try? dataSource.place(forIndex: previousIndex) {
            if let prevVC = previousCardView {
                prevVC.updateUI(forPlace: previousPlace, withUserLocation: userLocation)
            } else {
                initCardView(forPrevious: previousPlace)
            }
        }
    }

    /// Removes the given view from the view hierarchy if it exists, else no-op.
    private func removeCardView(_ view: PlaceDetailsCardView?) {
        guard let view = view else { return }
        view.removeFromSuperview()
        view.isHidden = false
    }

    fileprivate func dequeuePlaceCardView(forPlace place: Place) -> PlaceDetailsCardView {
        let newView = PlaceDetailsCardView(place: place, userLocation: locationProvider.getCurrentLocation())
        newView.imageCarousel.delegate = self
        newView.delegate = self
        newView.alpha = cardFadeOutAlpha
        return newView
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

                let currentCenter = currentCardView.center
                currentCardView.alpha = calculateAlpha(forCenterPosition: currentCenter)

                if let nextCenter = nextCardView?.center {
                    nextCardView?.alpha = calculateAlpha(forCenterPosition: nextCenter)
                }

                if let prevCenter = previousCardView?.center {
                    previousCardView?.alpha = calculateAlpha(forCenterPosition: prevCenter)
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
        return finalXPosition < -(self.view.frame.width * 0.5) && self.nextCardView != nil
    }

    fileprivate func pageToNextPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        guard let nextCardView = nextCardView  else {
            return
        }

        self.currentCardView.imageCarousel.stopAutoMove()
        
        // check to see if there is a next card to the next card
        // add a new view to next card view
        // if so, remove currentCardView centerX constraint
        // add center x constraint to nextCardView
        
        let nextCardImageCarousel = addImageCarousel(forNextCard: nextCardView)

        previousCardView?.isHidden = true

        let newnextCardView = insertNewCardView(forPlace: dataSource?.nextPlace(forPlace: nextCardView.place))
        newnextCardView?.transform = scaleOutTransformRight

        let springDamping:CGFloat = newnextCardView == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: currentCardView, newCurrentCard: nextCardView, newNextCard: newnextCardView)

        view.layoutIfNeeded()

        // setup constraints for new central card
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = nextCardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([self.currentCardViewCenterXConstraint!])

        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            nextCardImageCarousel.alpha = 1
            nextCardView.alpha = 1
            self.currentCardView.alpha = cardFadeOutAlpha
            self.setBackgroundImage(toPhotoAtURL: nextCardView.place.photoURLs.first)
            self.view.layoutIfNeeded()

            self.nextCardView?.transform = CGAffineTransform.identity
            self.currentCardView.transform = scaleOutTransformLeft
        }, completion: { finished in
            if finished {
                // ensure that the correct current, previous and next view references are set
                self.imageCarousel.removeFromSuperview()
                self.imageCarousel = nextCardImageCarousel
                self.currentCardView.removeGestureRecognizer(self.panGestureRecognizer)
                self.removeCardView(self.previousCardView)
                self.previousCardView = self.currentCardView
                self.currentCardView = nextCardView
                self.nextCardView = newnextCardView
                self.placeDetailsCardView(cardView: self.currentCardView, heightDidChange: self.currentCardView.frame.height)

                self.currentCardView.imageCarousel.beginAutoMove()

                let cardPos = self.dataSource?.index(forPlace: self.currentCardView.place) ?? -1
                AppState.trackCardVisit(cardPos: cardPos)
            }
        })
    }

    fileprivate func canPageToPreviousPlaceCard(finalXPosition: CGFloat) -> Bool {
        return finalXPosition > (self.view.frame.width * 0.5) && self.previousCardView != nil
    }

    // check to see if there is a previous card to the previous card
    // add a new view to previous card view
    // if so, remove currentCardView centerX constraint
    // add center x constraint to previousCardView
    fileprivate func pageToPreviousPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        guard let previousCardView = previousCardView else {
            return
        }

        self.currentCardView.imageCarousel.stopAutoMove()

        // add the image carousel for the previous place card underneath the existing carousel
        // we need to ensure these constraints are applied and rendered before we animate the rest, otherwise we end
        // up with a very odd looking fade transition
        let previousCardImageCarousel = addImageCarousel(forNextCard: previousCardView)

        nextCardView?.isHidden = true

        let newpreviousCardView = insertNewCardView(forPlace: dataSource?.previousPlace(forPlace: previousCardView.place))
        newpreviousCardView?.transform = scaleOutTransformLeft

        let springDamping:CGFloat = newpreviousCardView == nil ? 0.8 : 1.0
        setupConstraints(forNewPreviousCard: newpreviousCardView, newCurrentCard: previousCardView, newNextCard: currentCardView)

        view.layoutIfNeeded()

        // deactivate and remove current view center constraint
        if let currentCardViewCenterXConstraint = currentCardViewCenterXConstraint {
            NSLayoutConstraint.deactivate([currentCardViewCenterXConstraint])
        }

        self.currentCardViewCenterXConstraint = previousCardView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        NSLayoutConstraint.activate([currentCardViewCenterXConstraint!])

        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: springDamping, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.imageCarousel.alpha = 0
            previousCardImageCarousel.alpha = 1
            previousCardView.alpha = 1
            self.currentCardView.alpha = cardFadeOutAlpha
            self.setBackgroundImage(toPhotoAtURL: previousCardView.place.photoURLs.first)
            self.view.layoutIfNeeded()

            self.previousCardView?.transform = CGAffineTransform.identity
            self.currentCardView.transform = scaleOutTransformRight
        }, completion: { finished in
            if finished {
                self.currentCardView.removeGestureRecognizer(self.panGestureRecognizer)
                self.removeCardView(self.nextCardView)
                self.imageCarousel.removeFromSuperview()
                self.imageCarousel = previousCardImageCarousel
                self.nextCardView = self.currentCardView
                self.currentCardView = previousCardView
                self.previousCardView = newpreviousCardView
                self.placeDetailsCardView(cardView: self.currentCardView, heightDidChange: self.currentCardView.frame.height)

                self.currentCardView.imageCarousel.beginAutoMove()
                let cardPos = self.dataSource?.index(forPlace: self.currentCardView.place) ?? -1
                AppState.trackCardVisit(cardPos: cardPos)
            }
        })
    }

    fileprivate func insertNewCardView(forPlace place: Place?) -> PlaceDetailsCardView? {
        guard let newPlace = place else {
            return nil
        }

        let newCardView = dequeuePlaceCardView(forPlace:newPlace)
        self.scrollView.addSubview(newCardView)
        // Constraint duplication with updateCurrentCardConstraints & initCardView(*.
        NSLayoutConstraint.activate([newCardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardViewTopAnchorConstant),
                                     newCardView.widthAnchor.constraint(equalToConstant: cardViewWidth)], translatesAutoresizingMaskIntoConstraints: false)
        return newCardView
    }

    fileprivate func setupConstraints(forNewPreviousCard newPreviousCard: PlaceDetailsCardView?, newCurrentCard: PlaceDetailsCardView, newNextCard: PlaceDetailsCardView?) {
        var constraintsToDeactivate = [NSLayoutConstraint]()
        var constraintsToActivate = [NSLayoutConstraint]()

        if let previousCardViewTrailingConstraint = previousCardViewTrailingConstraint {
            constraintsToDeactivate += [previousCardViewTrailingConstraint]
        }
        if let previousCard = newPreviousCard {
            self.previousCardViewTrailingConstraint = previousCard.trailingAnchor.constraint(equalTo: newCurrentCard.leadingAnchor, constant: -cardViewSpacingConstant)
            constraintsToActivate += [self.previousCardViewTrailingConstraint!]
        } else {
            previousCardViewTrailingConstraint = nil
        }

        if let nextCardViewLeadingConstraint = nextCardViewLeadingConstraint {
            constraintsToDeactivate += [nextCardViewLeadingConstraint]
        }
        if let nextCard = newNextCard {
            self.nextCardViewLeadingConstraint = nextCard.leadingAnchor.constraint(equalTo: newCurrentCard.trailingAnchor, constant: cardViewSpacingConstant)
            constraintsToActivate += [self.nextCardViewLeadingConstraint!]
        } else {
            nextCardViewLeadingConstraint = nil
        }

        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        NSLayoutConstraint.activate(constraintsToActivate, translatesAutoresizingMaskIntoConstraints: false)

        self.addGestureRecognizers(toView: newCurrentCard)
    }

    fileprivate func unwindToCurrentPlaceCard(animateWithDuration animationDuration: TimeInterval) {
        currentCardViewCenterXConstraint?.constant = 0
        UIView.animate(withDuration: animationDuration, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.nextCardView?.alpha = cardFadeOutAlpha
            self.previousCardView?.alpha = cardFadeOutAlpha
            self.currentCardView?.alpha = 1.0
            self.view.layoutIfNeeded()
        }, completion: nil )
    }

    fileprivate func addImageCarousel(forNextCard nextCard: PlaceDetailsCardView) -> UIView {
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

    @objc private func openMapView() {
        let controller = MapViewController(selectedPlace: currentPlace, enabledFilters: dataSource?.enabledFilters ?? Set())
        controller.delegate = self
        controller.placesProvider = dataSource
        controller.locationProvider = locationProvider
        self.present(controller, animated: true)

        slideCurrentCardView(willBeShown: false)
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

extension PlaceDetailViewController: PlaceDetailsCardDelegate {
    func placeDetailsCardView(cardView: PlaceDetailsCardView, heightDidChange newHeight: CGFloat) {
        guard cardView == currentCardView else {
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

    func placeDetailsCardView(cardView: PlaceDetailsCardView, directionsRequestedTo place: Place, by transportType: MKDirectionsTransportType) {
        guard let coord = locationProvider.getCurrentLocation()?.coordinate else { return }
        OpenInHelper.openRoute(fromLocation: coord, toPlace: place, by: transportType, analyticsStr: AnalyticsEvent.DIRECTIONS, errStr: "unable to open travel directions")
    }
}
extension PlaceDetailViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == scrollView.panGestureRecognizer
    }
}

extension PlaceDetailViewController: FilterViewControllerDelegate {
    func filterViewController(_ filterViewController: FilterViewController, didUpdateFilters enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        guard let places = dataSource?.getPlaces() else { return }
        filterViewController.placeCount = PlaceUtilities.filter(places: places.allPlaces, withFilters: enabledFilters).count
    }

    func filterViewController(_ filterViewController: FilterViewController, didDismissWithFilters enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        guard let dataSource = dataSource else { return }
        if dataSource.enabledFilters != enabledFilters || dataSource.topRatedOnly != topRatedOnly {
            dataSource.refresh(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)
        }

        slideCurrentCardView(willBeShown: true)
    }
}

extension PlaceDetailViewController: MapViewControllerDelegate {
    func mapViewController(_ mapViewController: MapViewController, didDismissWithSelectedPlace place: Place?) {
        if let place = place {
            openCard(forExistingPlace: place)
        }

        slideCurrentCardView(willBeShown: true)
    }
}
