/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class ReviewScoreView: UIStackView {

    var color: UIColor? {
        didSet {
            for subview in arrangedSubviews {
                if let subview = subview as? ReviewScoreItemView {
                    subview.color = color
                }
            }
        }
    }
    var score: Int = 0 {
        didSet {
            for (index, subview) in arrangedSubviews.enumerated() {
                if let subview = subview as? ReviewScoreItemView {
                    subview.fill = index < score
                }
            }
        }
    }

    convenience init() {
        self.init(score: 0)
    }

    init(score: Int) {
        super.init(frame: .zero)

        self.score = score

        distribution = .equalSpacing
        axis = .horizontal
        alignment = .center
        spacing = 0

        for index in 0..<5 {
            let scoreItem = ReviewScoreItemView()
            scoreItem.color = color
            scoreItem.backgroundColor = .clear
            scoreItem.fill = index < score
            addArrangedSubview(scoreItem)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width: CGFloat = frame.width / 6
        let height: CGFloat = frame.height / 3
        for subview in arrangedSubviews {
            subview.widthAnchor.constraint(equalToConstant: width).isActive = true
            subview.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }

}

private class ReviewScoreItemView: UIView {

    var color: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }
    var fill: Bool = false {
        didSet {
            if fill != oldValue {
                setNeedsDisplay()
            }
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        if let context = UIGraphicsGetCurrentContext() {
            if fill {
                context.setFillColor(color?.cgColor ?? UIColor.black.cgColor)
            } else {
                context.setFillColor(Colors.reviewScoreDefault.cgColor)
            }
            context.fillEllipse(in: rect)
        }
    }

}
