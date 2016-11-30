/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

protocol InAppNotificationToastDelegate: class {
    func inAppNotificationToastProvider(_ toast: InAppNotificationToastProvider, userDidRespondToNotificationForEventWithId eventId: String, atPlaceWithId placeId: String)
    func inAppNotificationToastProviderDidDismiss(_ toast: InAppNotificationToastProvider)
}

class InAppNotificationToastProvider: NSObject {

    fileprivate let placeId: String
    fileprivate let eventId: String

    fileprivate lazy var notificationView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.notificationBackground
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userDidRespondToToast(recognizer:))))
        return view
    }()

    fileprivate lazy var notificationLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = Colors.notificationText
        label.font = Fonts.notificationText
        label.backgroundColor = .clear
        label.textAlignment = .center
        return label
    }()

    fileprivate var presentationTimer: Timer?

    weak var delegate: InAppNotificationToastDelegate?

    init(placeId: String, eventId: String, text: String) {
        self.placeId = placeId
        self.eventId = eventId
        super.init()
        notificationLabel.text = text

        setupSubviews()
    }

    fileprivate func setupSubviews() {
        notificationView.addSubview(notificationLabel)

        NSLayoutConstraint.activate([notificationLabel.centerXAnchor.constraint(equalTo: notificationView.centerXAnchor),
                                         notificationLabel.centerYAnchor.constraint(equalTo: notificationView.centerYAnchor),
                                         notificationLabel.widthAnchor.constraint(equalTo: notificationView.widthAnchor, multiplier: 0.75),
                                         notificationView.topAnchor.constraint(equalTo: notificationLabel.topAnchor, constant: -10),
                                         notificationView.bottomAnchor.constraint(equalTo: notificationLabel.bottomAnchor, constant: 10 )],
                                    translatesAutoresizingMaskIntoConstraints: false)
    }

    func presentOnView(_ view: UIView) {
        view.addSubview(notificationView)
        NSLayoutConstraint.activate([notificationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     notificationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     notificationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)],
                                    translatesAutoresizingMaskIntoConstraints: false)
        view.bringSubview(toFront: notificationView)

        presentationTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(dismiss), userInfo: nil, repeats: false)
    }

    func dismiss() {
        notificationView.removeFromSuperview()
        presentationTimer?.invalidate()
        delegate?.inAppNotificationToastProviderDidDismiss(self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc fileprivate func userDidRespondToToast(recognizer: UITapGestureRecognizer) {
        delegate?.inAppNotificationToastProvider(self, userDidRespondToNotificationForEventWithId: eventId, atPlaceWithId: placeId)
        dismiss()
    }

}
