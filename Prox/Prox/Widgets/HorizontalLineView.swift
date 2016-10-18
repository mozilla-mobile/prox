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

        // draw the line
        if let context = UIGraphicsGetCurrentContext() {

            // set the stroke color and width
            context.setStrokeColor(color.cgColor);
            context.setLineWidth(1.5);

            // move to first point
            context.move(to: CGPoint(x: startX ?? rect.width, y: startY ?? rect.height))

            // add a line to  second point
            context.addLine(to: CGPoint(x: endX ?? rect.width, y: endY ?? rect.height))

            // draw the line
            context.strokePath()
        }
    }

}
