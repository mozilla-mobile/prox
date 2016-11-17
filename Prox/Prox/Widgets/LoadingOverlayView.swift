/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

/// Overlay view shown on top of the PlaceCarouselViewController while loading.
class LoadingOverlayView: UIView {
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

    fileprivate lazy var restartButton: UIButton = {
        let btn = UIButton(frame: CGRect.zero)
        btn.backgroundColor = Colors.restartButtonColor
        let title = NSLocalizedString("Loading.Restart.Button",
                                      value: "Restart Prox",
                                      comment: "Title for button to restart prox")
        btn.layer.cornerRadius = 10
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = Fonts.loadingRestartButton
        return btn
    }()

    fileprivate var labelTop: NSLayoutConstraint?
    fileprivate var buttonTop: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        var constraintsToAdd = [NSLayoutConstraint]()

        addSubview(loadingAnimation)
        constraintsToAdd += [
            loadingAnimation.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            loadingAnimation.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -60)
        ]

        addSubview(messageLabel)

        let labelTop = messageLabel.topAnchor.constraint(equalTo: loadingAnimation.bottomAnchor, constant: 100)
        self.labelTop = labelTop
        constraintsToAdd += [
            labelTop,
            messageLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 16),
            messageLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16),
        ]

        addSubview(restartButton)

        let buttonTop = restartButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 100)
        self.buttonTop = buttonTop
        constraintsToAdd += [
            buttonTop,
            restartButton.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 16),
            restartButton.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16),
            restartButton.heightAnchor.constraint(equalToConstant: 54)
        ]

        NSLayoutConstraint.activate(constraintsToAdd, translatesAutoresizingMaskIntoConstraints: false)

        // Start with the error messaging hidden
        restartButton.alpha = 0
        messageLabel.alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            self.restartButton.alpha = 1
            self.layoutIfNeeded()
        }, completion: { _ in })
    }
}
