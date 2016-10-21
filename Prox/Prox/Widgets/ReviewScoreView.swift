/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class ReviewScoreView: UIStackView {

    var color: UIColor {
        didSet {
            if color != oldValue {
                updateReviewScore(score: self.score)
            }
        }
    }

    var score: Float = 0.0 {
        didSet {
            updateReviewScore(score: score)
        }
    }

    convenience init(color: UIColor) {
        self.init(score: 0, color: color)
    }

    init(score: Float, color: UIColor) {
        self.score = score
        self.color = color

        super.init(frame: .zero)

        distribution = .equalSpacing
        axis = .horizontal
        alignment = .center
        spacing = 0

        for index in 0..<5 {
            let scoreItem = ReviewScoreItemView(filledColor: self.color, unfilledColor: Colors.reviewScoreDefault)
            scoreItem.backgroundColor = .clear
            let scoreRemaining = self.score - Float(index)
            setFillScore(score: scoreRemaining, forView: scoreItem)
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

    private func updateReviewScore(score: Float) {
        for (index, subview) in arrangedSubviews.enumerated() {
            if let scoreItem = subview as? ReviewScoreItemView {
                let scoreRemaining = self.score - Float(index)
                setFillScore(score: scoreRemaining, forView: scoreItem)
            }
        }
    }

    private func setFillScore(score: Float, forView view: ReviewScoreItemView) {
        if score >= 1 {
            view.fillType = .full
        } else if score > 0 {
            view.fillType = .half
        } else {
           view.fillType = .empty
        }
    }

}

private enum FillAmount {
    case full
    case half
    case empty
}

private class ReviewScoreItemView: UIView {

    var filledColor: UIColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var unfilledColor: UIColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var fillType: FillAmount = .empty

    init(filledColor: UIColor, unfilledColor: UIColor) {
        self.filledColor = filledColor
        self.unfilledColor = unfilledColor
        super.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let width = rect.size.width / 2

        let leftColor: UIColor
        let rightColor: UIColor

        switch fillType {
        case .full:
            leftColor = filledColor
            rightColor = filledColor
        case .half:
            leftColor = filledColor
            rightColor = unfilledColor
        case .empty:
            leftColor = unfilledColor
            rightColor = unfilledColor
        }

        let leftHalf = UIBezierPath(roundedRect: CGRect(x: rect.origin.x, y: rect.origin.x, width: width, height: rect.size.height), byRoundingCorners: [UIRectCorner.topLeft, UIRectCorner.bottomLeft], cornerRadii: CGSize(width: 10, height: 10))
        leftHalf.close()
        leftColor.setFill()
        leftHalf.fill()

        let rightHalf = UIBezierPath(roundedRect: CGRect(x: rect.origin.x + width, y: rect.origin.x, width: width, height: rect.size.height), byRoundingCorners: [UIRectCorner.topRight, UIRectCorner.bottomRight], cornerRadii: CGSize(width: 10, height: 10))
        rightHalf.close()
        rightColor.setFill()
        rightHalf.fill()
    }

}
