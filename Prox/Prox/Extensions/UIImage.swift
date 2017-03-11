/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

extension UIImage {

    /// Creates a scaled image with the given height, maintaining the current aspect ratio.
    func createScaled(withHeight newHeight: CGFloat) -> UIImage {
        let newWidth = size.width * newHeight / size.height
        return createScaled(CGSize(width: newWidth, height: newHeight))
    }
}
