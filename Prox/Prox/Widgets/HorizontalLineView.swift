/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class HorizontalLineView: UIView {

    var color: UIColor = .white
    var startX: CGFloat?
    var endX: CGFloat?
    var startY: CGFloat?
    var endY: CGFloat?

    // draw the horizontal line at the bottom of the view
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        self.backgroundColor = .clear

        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: startX ?? rect.width, y: startY ?? rect.height))
        bezier2Path.addLine(to: CGPoint(x: endX ?? rect.width, y: endY ?? rect.height))
        color.setStroke()
        bezier2Path.lineWidth = 1.5
        bezier2Path.stroke()
    }

}
