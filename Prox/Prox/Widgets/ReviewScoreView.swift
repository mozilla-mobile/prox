/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class ReviewScoreView: UIStackView {

    var color: UIColor? {
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

    convenience init() {
        self.init(score: 0)
    }

    init(score: Float) {
        super.init(frame: .zero)

        self.score = score

        distribution = .equalSpacing
        axis = .horizontal
        alignment = .center
        spacing = 0

        for index in 0..<5 {
            let scoreItem = ReviewScoreItemView()
            scoreItem.backgroundColor = .clear
            let scoreLeft = self.score - Float(index)
            setFillScore(score: scoreLeft, forView: scoreItem)
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
                let scoreLeft = self.score - Float(index)
                setFillScore(score: scoreLeft, forView: scoreItem)
            }
        }
    }

    private func setFillScore(score: Float, forView view: ReviewScoreItemView) {
        if score >= 1 {
            view.leftColor = color
            view.rightColor = color
        } else if score > 0 {
            view.leftColor = color
            view.rightColor = Colors.reviewScoreDefault
        } else {
            view.leftColor = Colors.reviewScoreDefault
            view.rightColor = Colors.reviewScoreDefault
        }
    }

}

private class ReviewScoreItemView: UIView {

    var leftColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }

    var rightColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let width = rect.size.width / 2

        let leftHalf = UIBezierPath(roundedRect: CGRect(x: rect.origin.x, y: rect.origin.x, width: width, height: rect.size.height), byRoundingCorners: [UIRectCorner.topLeft, UIRectCorner.bottomLeft], cornerRadii: CGSize(width: 10, height: 10))
        leftHalf.close()
        (leftColor ?? UIColor.black).setFill()
        leftHalf.fill()

        let rightHalf = UIBezierPath(roundedRect: CGRect(x: rect.origin.x + width, y: rect.origin.x, width: width, height: rect.size.height), byRoundingCorners: [UIRectCorner.topRight, UIRectCorner.bottomRight], cornerRadii: CGSize(width: 10, height: 10))
        rightHalf.close()
        (rightColor ?? UIColor.black).setFill()
        rightHalf.fill()
    }

}
