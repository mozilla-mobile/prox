/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/*
 * MapPlacesTransition implements `UIViewControllerAnimatedTransitioning` and contains all of the animation
 * logic for presenting the place card carousel from the map view and dismissing it back to the maps view.
 * Most of the tricks that are used in the animation involve setting up fake copies of various views to add
 * to the animation context for translating/alpha effects. The code structure between dismissing and presenting
 * are very similar but I've kept them explicit to aid in readability.
 */
class MapPlacesTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var presenting: Bool = false

    // Scaling factor for the map view when we animate away. This gives the 'expanding' effect.
    private let scale: CGFloat = 1.1

    fileprivate let duration: TimeInterval = 0.6

    override init() {
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {

        // Setup all the views/view controller we'll need for animating
        let containerView = transitionContext.containerView
        guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
              let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
              let placesVC = (presenting ? toVC : fromVC) as? PlaceDetailViewController,
              let mapVC = (presenting ? fromVC : toVC) as? PlaceCarouselViewController,
              let placesView = placesVC.view,
              let mapsView = mapVC.view else {
            return
        }

        let placesViews = placesVC.animatableProperties()
        let currentPlace = placesVC.currentPlace

        // Create some local variables to help reference the views in the placesVC
        let placesImageCarousel = placesVC.imageCarousel!
        let placesCardView = placesViews.currentCard

        // Either place the places carousel above the current context or below depending on
        // if we are presenting or not
        if presenting {
            containerView.addSubview(placesView)
        } else {
            containerView.insertSubview(mapsView, belowSubview: placesView)
        }
        containerView.layoutIfNeeded()

        if presenting {
            guard let selectedCell = mapVC.placeCarousel.visibleCellFor(place: currentPlace),
                  let imageURL = URL(string: placesVC.currentPlace.photoURLs.first ?? "") else {
                return
            }

            let cellViews = selectedCell.animatableProperties()

            placesImageCarousel.alpha = 0

            // Convert the frame from the placeImages in the cell to the container's coordinates
            let placesImageFrame = cellViews.placeImage.frame
            let convertedPlacesImageFrame = containerView.convert(placesImageFrame, from: selectedCell)

            // Setup the fake collection view views for the animation
            let fakeImageView = UIImageView(frame: convertedPlacesImageFrame)
            fakeImageView.contentMode = UIViewContentMode.scaleAspectFill
            fakeImageView.clipsToBounds = true
            fakeImageView.layer.cornerRadius = 5
            fakeImageView.setImageWith(imageURL)

            let opacityView = createOpacityImageOverlay(frame: convertedPlacesImageFrame)

            let labelsSnapshot = snapshotOf(labelsContainer: cellViews.labelContainer)
            let labelsView = UIImageView(image: labelsSnapshot!)
            labelsView.frame = convertedPlacesImageFrame

            // Insert the fake image below the card along with the related views
            let cardParent = placesViews.currentCard.superview!
            cardParent.insertSubview(fakeImageView, belowSubview: placesViews.currentCard)
            cardParent.insertSubview(opacityView, aboveSubview: fakeImageView)
            cardParent.insertSubview(labelsView, aboveSubview: opacityView)

            // Hide the next/previous cards until we finish the animation
            placesViews.nextCard?.alpha = 0
            placesViews.previousCard?.alpha = 0
            placesViews.mapButton.alpha = 0
            placesViews.mapButtonBadge.alpha = 0
            placesViews.backgroundImage.alpha = 0

            // Hide the selected cell's image since we're using a fake one to animate
            cellViews.placeImage.alpha = 0

            // Moving of the card
            let endingCardOrigin = placesCardView.frame.origin
            let startingCardOrigin = CGPoint(x: placesCardView.frame.origin.x, y: UIScreen.main.bounds.height)
            placesCardView.frame = CGRect(origin: startingCardOrigin, size: placesCardView.frame.size)

            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0.5, options: .curveEaseInOut,
                           animations: {
                placesCardView.frame = CGRect(origin: endingCardOrigin, size: placesCardView.frame.size)
                fakeImageView.frame = placesImageCarousel.frame
                opacityView.frame = placesImageCarousel.frame

                fakeImageView.layer.cornerRadius = 0
                opacityView.layer.cornerRadius = 0

                mapsView.transform = CGAffineTransform.init(scaleX: self.scale, y: self.scale)

                mapsView.alpha = 0
                opacityView.alpha = 0
                labelsView.alpha = 0
            }, completion: { _ in
                fakeImageView.removeFromSuperview()
                mapsView.removeFromSuperview()
                opacityView.removeFromSuperview()
                labelsView.removeFromSuperview()

                placesImageCarousel.alpha = 1
                selectedCell.placeImage.alpha = 1

                transitionContext.completeTransition(true)
            })

            // Delay the views from the places view controller a bit so we don't cover the animation with the background image
            fadeDelay(placesViews: placesViews, show: true, delay: duration * 1/6, duration: duration  * 1/4)
        } else {
            // Since we could be at a different place than the one we selected to enter the detail view,
            // make sure we scroll the carousel to the new view before doing anything
            let currentPlace = placesVC.currentPlace
            mapVC.placeCarousel.scrollTo(place: currentPlace)
            mapsView.layoutIfNeeded()

            guard let toPlacesCell = mapVC.placeCarousel.visibleCellFor(place: currentPlace),
                  let imageURL = URL(string: placesVC.currentPlace.photoURLs.first ?? "") else {
                return
            }

            let cellViews = toPlacesCell.animatableProperties()

            // Scale back the maps view to calculate the frames correctly, then scale back down
            mapsView.transform = CGAffineTransform.identity

            // Convert the frame from the placeImages in the cell to the container's coordinates
            let placesImageFrame = cellViews.placeImage.frame
            let convertedPlacesImageFrame = placesView.convert(placesImageFrame, from: toPlacesCell)

            // Setup the fake views we'll need to perform the animation
            let fakeImageView = UIImageView(frame: placesVC.imageCarousel.frame)
            fakeImageView.contentMode = UIViewContentMode.scaleAspectFill
            fakeImageView.clipsToBounds = true
            fakeImageView.backgroundColor = .red
            fakeImageView.setImageWith(imageURL)

            let opacityView = createOpacityImageOverlay(frame: placesVC.imageCarousel.frame)
            opacityView.alpha = 0
            opacityView.layer.cornerRadius = 0

            let labelsSnapshot = snapshotOf(labelsContainer: cellViews.labelContainer)
            let labelsView = UIImageView(image: labelsSnapshot)
            labelsView.frame = convertedPlacesImageFrame
            labelsView.alpha = 0

            containerView.insertSubview(fakeImageView, aboveSubview: placesVC.imageCarousel)
            containerView.insertSubview(opacityView, aboveSubview: fakeImageView)
            containerView.insertSubview(labelsView, aboveSubview: opacityView)

            // Hide the actual carousel
            placesImageCarousel.alpha = 0

            // Setup our frame values for the card animation
            let startingCardOrigin = placesCardView.frame.origin
            let endingCardOrigin = CGPoint(x: placesCardView.frame.origin.x, y: UIScreen.main.bounds.height)
            placesCardView.frame = CGRect(origin: startingCardOrigin, size: placesCardView.frame.size)

            // Setup maps view to scale in
            mapsView.alpha = 0
            mapsView.transform = CGAffineTransform.init(scaleX: self.scale, y: self.scale)

            // Hide the selected cell's image since we're using a fake one to animate
            cellViews.placeImage.alpha = 0

            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1,
                           initialSpringVelocity: 0.5, options: .curveEaseInOut,
                           animations: {
                placesCardView.frame = CGRect(origin: endingCardOrigin, size: placesCardView.frame.size)
                fakeImageView.frame = convertedPlacesImageFrame
                opacityView.frame = convertedPlacesImageFrame

                fakeImageView.layer.cornerRadius = 5
                opacityView.layer.cornerRadius = 5
                
                mapsView.transform = CGAffineTransform.identity
                
                mapsView.alpha = 1
                opacityView.alpha = 1
                labelsView.alpha = 1
            }, completion: { _ in
                fakeImageView.removeFromSuperview()
                placesView.removeFromSuperview()
                opacityView.removeFromSuperview()
                labelsView.removeFromSuperview()

                cellViews.placeImage.alpha = 1
                
                transitionContext.completeTransition(true)
            })

            fadeDelay(placesViews: placesViews, show: false, delay: 0, duration: duration * 1/4)
        }
    }

    // Fade in the previous/next cards after a bit of a delay depending on if we're presenting/dismissing
    fileprivate func fadeDelay(placesViews: PlaceDetailAnimatableViews, show: Bool,
                               delay: TimeInterval, duration: TimeInterval) {

        // For some reason, the delay in the UIView.animate call wasn't working when performed at the same time
        // as another animation. I've wrapped it in a DispatchQueue...asyncAfter instead to achieve the delay.
        let dispatchTime = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(delay * 1000))
        DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut,
                           animations: {
                placesViews.nextCard?.alpha = show ? 0.6 : 0
                placesViews.previousCard?.alpha = show ? 0.6 : 0
                placesViews.mapButton.alpha = show ? 1 : 0
                placesViews.mapButtonBadge.alpha = show ? 1 : 0
                placesViews.backgroundImage.alpha = show ? 1 : 0
            }, completion: { _ in })
        }
    }

    // Helper methods for creating the fake views we need
    fileprivate func createOpacityImageOverlay(frame: CGRect) -> UIView {
        let opacityView = UIView(frame: frame)
        opacityView.backgroundColor = Colors.carouselViewImageOpacityLayer
        opacityView.translatesAutoresizingMaskIntoConstraints = false
        opacityView.layer.cornerRadius = 5
        return opacityView
    }

    fileprivate func snapshotOf(labelsContainer: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(labelsContainer.frame.size, false, UIScreen.main.scale)
        if let ctx = UIGraphicsGetCurrentContext() {
            labelsContainer.layer.render(in: ctx)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

