/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class Toast {
    private let text: String

    init(text: String) {
        self.text = text
    }

    func show() {
        assert(Thread.isMainThread)
        guard let window = UIApplication.shared.windows.first else { return }

        let toast = UIView()
        toast.alpha = 0
        toast.backgroundColor = Colors.toastBackground
        toast.layer.cornerRadius = 18
        window.addSubview(toast)

        let label = UILabel()
        label.text = text
        label.textColor = Colors.toastText
        label.font = Fonts.toast
        label.numberOfLines = 0
        toast.addSubview(label)

        toast.snp.makeConstraints { make in
            make.bottom.equalTo(window).offset(-30)
            make.centerX.equalTo(window)
            make.leading.greaterThanOrEqualTo(window)
            make.trailing.lessThanOrEqualTo(window)
        }

        label.snp.makeConstraints { make in
            make.leading.trailing.equalTo(toast).inset(20)
            make.top.bottom.equalTo(toast).inset(10)
        }

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 3, options: [], animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        })
    }
}
