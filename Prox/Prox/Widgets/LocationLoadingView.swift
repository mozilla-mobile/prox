/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import QuartzCore

/// Create a CAShapeLayer filled with a circle with the given color and bounds.
///
/// - Parameters:
///   - color: Fill color of the circle
///   - frame: Frame/bounds of the circle shape
/// - Returns: CAShapeLayer filled with a circle
fileprivate func createCircle(color: CGColor, frame: CGRect) -> CAShapeLayer {
    let circle = CAShapeLayer()
    circle.path = CGPath(ellipseIn: frame, transform: nil)
    circle.fillColor = color
    circle.frame = frame
    return circle
}

/// Generates an CAAnimation from `fromState` to `toState`. The animation group contains
/// both the fade out/out effect and frame change.
///
/// - Parameters:
///   - fromState: State to transition from
///   - toState: State to transition to
/// - Returns: CAAnimationGroup containing the size/opacity changes when from state to state
fileprivate func animation(fromState: CircleState, toState: CircleState) -> CAAnimationGroup {
    let sizeChange = CABasicAnimation(keyPath: "transform")
    let fromTransform = CGAffineTransform(scaleX: fromState.scale, y: fromState.scale)
    let toTransform = CGAffineTransform(scaleX: toState.scale, y: toState.scale)

    sizeChange.fromValue = NSValue(caTransform3D: CATransform3DMakeAffineTransform(fromTransform))
    sizeChange.toValue = NSValue(caTransform3D: CATransform3DMakeAffineTransform(toTransform))

    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = fromState.opacity
    fade.toValue = toState.opacity
    
    let group = CAAnimationGroup()
    group.animations = [fade, sizeChange]
    group.duration = 1.6
    group.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    group.repeatCount = Float.greatestFiniteMagnitude
    group.autoreverses = true
    return group
}

/// Represents the shrunk/enlarged circle state
fileprivate enum CircleState {
    case enlarged
    case shrunk

    var scale: CGFloat {
        switch self {
        case .enlarged: return 1.2
        case .shrunk: return 0.9
        }
    }

    var opacity: Float {
        switch self {
        case .enlarged: return 0.1
        case .shrunk: return 0.3
        }
    }

    func next() -> CircleState {
        switch self {
        case .enlarged: return .shrunk
        case .shrunk: return .enlarged
        }
    }
}


/// A view containing a blue dot in the middle with two overlapping circles throbbing.
class LocationLoadingView: UIView {
    fileprivate let circleA: CAShapeLayer
    fileprivate let circleB: CAShapeLayer
    fileprivate let dot: UIImageView

    var fillColor: CGColor? {
        didSet {
            self.circleA.fillColor = fillColor
            self.circleB.fillColor = fillColor
        }
    }

    init(frame: CGRect, fillColor: UIColor) {
        self.circleA = createCircle(color: fillColor.cgColor, frame: frame)
        self.circleB = createCircle(color: fillColor.cgColor, frame: frame)
        self.dot = UIImageView(image: #imageLiteral(resourceName: "icon_loadingdot"))

        super.init(frame: frame)

        layer.addSublayer(self.circleA)
        layer.addSublayer(self.circleB)

        self.addSubview(self.dot)
        let dotConstraints = [
            self.dot.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.dot.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ]
        NSLayoutConstraint.activate(dotConstraints, translatesAutoresizingMaskIntoConstraints: false)

        let aAnim = animation(fromState: .shrunk, toState: .enlarged)
        self.circleA.add(aAnim, forKey: "a")

        let bAnim = animation(fromState: .enlarged, toState: .shrunk)
        self.circleB.add(bAnim, forKey: "b")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
