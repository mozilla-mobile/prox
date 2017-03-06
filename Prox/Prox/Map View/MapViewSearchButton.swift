/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

private let enabledColor = UIColor.blue

class MapViewSearchButton: UIButton {

    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? enabledColor : .gray
        }
    }

    init() {
        super.init(frame: .zero)
        isHidden = true

        backgroundColor = enabledColor
        layer.cornerRadius = 10

        setTitle(Strings.mapView.searchHere, for: .normal)
        setTitleColor(.white, for: .normal)

        setTitle(Strings.mapView.searching, for: .disabled)
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
