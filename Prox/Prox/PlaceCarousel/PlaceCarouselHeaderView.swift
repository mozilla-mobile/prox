/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceCarouselHeaderView: UIView {

    // label to display number of places
    lazy var numberOfPlacesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 50)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white

        self.setupViews()
    }

    // setting up the constraints for the views
    func setupViews() {
        addSubview(numberOfPlacesLabel)

        let constraints = [ numberOfPlacesLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
                            numberOfPlacesLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)]

        NSLayoutConstraint.activate(constraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // draw the horizontal line at the bottom of the view
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // draw the line
        if let context = UIGraphicsGetCurrentContext() {

            // set the stroke color and width
            context.setStrokeColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 1.0);
            context.setLineWidth(1.5);

            // move to first point
            context.move(to: CGPoint(x: 20.0, y: rect.height))

            // add a line to  second point
            context.addLine(to: CGPoint(x: rect.width, y: rect.height))

            // draw the line
            context.strokePath()
        }
    }

}
