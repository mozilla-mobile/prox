/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceCarouselHeaderView: UIView {

    // label to display number of places
    lazy var numberOfPlacesLabel: UILabel = {
        let label = UILabel()
        label.font = Fonts.carouselViewNumberOfPlaces
        return label
    }()

    fileprivate lazy var line: HorizontalLineView = HorizontalLineView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white

        line.startX = 20.0
        line.color = Colors.carouselViewHeaderHorizontalLine
        
        addSubview(numberOfPlacesLabel)
        addSubview(line)

        let constraints = [ numberOfPlacesLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
                            numberOfPlacesLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10),
                            line.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                            line.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                            line.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                            line.heightAnchor.constraint(equalToConstant: 1.5)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
