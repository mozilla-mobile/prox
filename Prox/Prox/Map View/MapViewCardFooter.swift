/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import SnapKit

private let cardPadding = 10
private let cardSpacing: CGFloat = 10

class MapViewCardFooter: ExpandingCardView {

    private lazy var containerView: UIView = {
        let container = UIView()
        for view in [
            self.coverPhotoView,
            self.titleLabel,
            ] as [UIView] {
            container.addSubview(view)
        }
        return container
    }()

    private lazy var coverPhotoView: UIImageView = {
        let view = UIImageView()
        view.image = #imageLiteral(resourceName: "place-placeholder")
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    private lazy var titleLabel: UILabel = UILabel()

    init(bottomInset: CGFloat) {
        super.init()
        initStyle()
        contentView = containerView

        coverPhotoView.snp.makeConstraints { make in
            make.height.equalTo(100)
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(titleLabel.snp.top).offset(-cardSpacing)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(cardPadding)
            make.bottom.equalToSuperview().offset(-cardSpacing - bottomInset)
        }

        titleLabel.text = "Placeholder place"
    }

    required init?(coder aDecoder: NSCoder) { fatalError("coder not implemented") }

    private func initStyle() {
        cornerRadius = Style.cardViewCornerRadius

        shadowOffset = Style.cardViewShadowOffset
        shadowRadius = Style.cardViewShadowRadius
        shadowOpacity = Style.cardViewShadowOpacity
    }
}
