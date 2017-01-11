/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class CrossFadeTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var completionCallback: (() -> Void)?

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }

    // This method can only  be a nop if the transition is interactive and not a percentDriven interactive transition.
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let toView = transitionContext.view(forKey: UITransitionContextViewKey.to),
              let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from) else {
                return 
        }

        toView.alpha = 0
        containerView.addSubview(toView)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseInOut, animations: {
            toView.alpha = 1
            fromView.alpha = 0
        }, completion: { _ in
            self.completionCallback?()
            transitionContext.completeTransition(true)
        })
    }
}
