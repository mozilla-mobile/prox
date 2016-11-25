/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class MapButton: UIButton {

    fileprivate let shadowRadius: CGFloat = 3

    fileprivate let mapImage = UIImage(named: "icon_mapview")

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let shadow = NSShadow()
        shadow.shadowColor = Colors.detailsViewMapButtonShadow
        shadow.shadowOffset = CGSize(width: 0.5, height: 0.75)
        shadow.shadowBlurRadius = shadowRadius

        // Drawing code
        let ovalPath = UIBezierPath(ovalIn: CGRect(x: (shadowRadius / 2) - shadow.shadowOffset.width, y: (shadowRadius / 2)  - shadow.shadowOffset.height, width: rect.width - shadowRadius, height: rect.height - shadowRadius))
        context.saveGState()
        context.setShadow(offset: shadow.shadowOffset, blur: shadow.shadowBlurRadius, color: (shadow.shadowColor as! UIColor).cgColor)
        Colors.detailsViewMapButtonBackground.setFill()
        ovalPath.fill()

        if let image = mapImage {
            let mapFrame = CGRect(x: rect.width / 2 - image.size.width / 2,
                                  y: rect.height / 2 - image.size.height / 2,
                                  width: image.size.width,
                                  height: image.size.height)
            context.draw(image.cgImage!, in: mapFrame)
        }
        
        context.restoreGState()
    }
}
