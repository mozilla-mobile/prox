/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol LoadingOverlayDelegate: class {
    func loadingOverlayDidTapSearchAgain()
}

/// Overlay view shown on top of the PlaceCarouselViewController while loading.
class LoadingOverlayView: UIView {
    weak var delegate: LoadingOverlayDelegate?

    fileprivate lazy var loadingAnimation = LocationLoadingView(fillColor: Colors.carouselLoadingViewColor)
    fileprivate lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Loading.Error.Label",
                                       value: "Uh oh, we can't seem to find any places nearby.",
                                       comment: "Message shown when we're unable to find any locations nearby.")
        label.font = Fonts.loadingErrorMessage
        label.textAlignment = .center
        label.numberOfLines = 2
        label.textColor = .black

        return label
    }()

    fileprivate lazy var searchAgainButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = Colors.restartButtonColor
        let title = NSLocalizedString("Loading.SearchAgain.Button",
                                      value: "Search again",
                                      comment: "Title for button to restart a search for places nearby")
        btn.layer.cornerRadius = 10
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = Fonts.loadingRestartButton
        btn.addTarget(self, action: #selector(didTapSearchAgainButton), for: .touchUpInside)
        return btn
    }()

    fileprivate var labelTop: NSLayoutConstraint?
    fileprivate var buttonTop: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        if let backgroundImage = UIImage(named: "map_background") {
            layer.contents = backgroundImage.cgImage
        }

        var constraintsToAdd = [NSLayoutConstraint]()

        addSubview(loadingAnimation)
        constraintsToAdd += [
            loadingAnimation.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            loadingAnimation.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ]

        addSubview(messageLabel)

        let labelTop = messageLabel.topAnchor.constraint(equalTo: loadingAnimation.bottomAnchor, constant: 100)
        self.labelTop = labelTop
        constraintsToAdd += [
            labelTop,
            messageLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 16),
            messageLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16),
        ]

        addSubview(searchAgainButton)

        let buttonTop = searchAgainButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 100)
        self.buttonTop = buttonTop
        constraintsToAdd += [
            buttonTop,
            searchAgainButton.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 16),
            searchAgainButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16),
            searchAgainButton.heightAnchor.constraint(equalToConstant: 54)
        ]

        NSLayoutConstraint.activate(constraintsToAdd, translatesAutoresizingMaskIntoConstraints: false)

        // Start with the error messaging hidden
        searchAgainButton.alpha = 0
        messageLabel.alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addAsSubview(on view: UIView) {
        view.addSubview(self)
        let constraints = [topAnchor.constraint(equalTo: view.topAnchor),
                           bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           leftAnchor.constraint(equalTo: view.leftAnchor),
                           rightAnchor.constraint(equalTo: view.rightAnchor)]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    @objc fileprivate func didTapSearchAgainButton() {
        fadeOutMessaging()
        self.delegate?.loadingOverlayDidTapSearchAgain()
    }

    func fadeInMessaging() {
        layoutIfNeeded()

        // Fade/animate in the text and button with a slight delay to make it look neat.
        UIView.animate(withDuration: 0.6, delay: 0, animations: {
            self.labelTop?.constant = 16
            self.messageLabel.alpha = 1
            self.layoutIfNeeded()
        }, completion: { _ in})

        UIView.animate(withDuration: 0.6, delay: 0.6, animations: {
            self.buttonTop?.constant = 16
            self.searchAgainButton.alpha = 1
            self.layoutIfNeeded()
        }, completion: { _ in })

        Analytics.logEvent(event: AnalyticsEvent.NO_PLACES_DIALOG, params: [:])
    }

    func fadeOutMessaging() {
        layoutIfNeeded()

        UIView.animate(withDuration: 0.6, delay: 0, animations: {
            self.labelTop?.constant = 100
            self.buttonTop?.constant = 100
            self.messageLabel.alpha = 0
            self.searchAgainButton.alpha = 0
            self.layoutIfNeeded()
        }, completion: { _ in})
    }
}
