/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceDetailsEventHeader: UIView {

    private let label: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewEventText
        view.text = Strings.detailsView.eventTitle
        view.font = Fonts.detailsViewEventText
        return view
    }()

    private let icon: UIImageView = {
        let view = UIImageView()
        view.image = #imageLiteral(resourceName: "icon_event")
        return view
    }()

    init() {
        super.init(frame: .zero)
        for view in [label, icon] as [UIView] { addSubview(view) }
        backgroundColor = Colors.detailsViewEventBackground

        icon.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview().inset(16)
        }

        label.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerY.equalTo(icon)
            make.leading.equalTo(icon.snp.trailing).offset(16)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("coder no") }
}
