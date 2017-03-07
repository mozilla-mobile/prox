/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let enabledColor = Colors.mapViewSearchButtonBackground

class MapViewSearchButton: UIButton {

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? enabledColor : Colors.mapViewSearchButtonDisabledBackground
        }
    }

    init() {
        super.init(frame: .zero)
        isHidden = true

        contentEdgeInsets = UIEdgeInsetsMake(10, 20, 10, 20)
        backgroundColor = enabledColor
        layer.cornerRadius = 20 // TODO technically we want frame.height / 2
        layer.shadowOpacity = 0.4
        layer.shadowColor = Colors.mapViewSearchButtonShadow
        layer.shadowOffset = CGSize(width: 0, height: 2)

        setTitle(Strings.mapView.searchHere, for: .normal)
        setTitleColor(Colors.mapViewSearchButtonText, for: .normal)

        setTitle(Strings.mapView.searching, for: .disabled)

        titleLabel?.font = Fonts.mapViewSearchButton
    }

    required init?(coder aDecoder: NSCoder) { fatalError("unused coder init") }

    func setIsHiddenWithAnimations(_ willHide: Bool) {
        if !willHide {
            isHidden = false
            alpha = 0
        }

        UIView.animate(withDuration: 0.6, animations: {
            self.alpha = willHide ? 0 : 1
        }, completion: { _ in
            self.isHidden = willHide
            if willHide {
                // Button should always be enabled when we start showing.
                self.isEnabled = true
            }
        })
    }
}
