/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceDetailsEventView: UIView {

    lazy var iconView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "icon_event")
        return view
    }()

    private lazy var textView: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewEventText
        view.textColor = Colors.detailsViewEventText
        view.numberOfLines = 0 // line count limited by constraints
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String, underlined underlinedText: String) {
        let underlineAttr = [NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue]
        let outStr = NSMutableAttributedString(string: underlinedText, attributes: underlineAttr)
        outStr.insert(NSAttributedString(string: text + " "), at: 0)
        textView.attributedText = outStr
    }

    func setupViews() {
        backgroundColor = Colors.detailsViewEventBackground

        addSubview(iconView)
        var constraints = [iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                           iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                           iconView.heightAnchor.constraint(equalToConstant: 28),
                           iconView.widthAnchor.constraint(equalToConstant: 28)]

        addSubview(textView)
        constraints += [textView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
                        textView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
                        textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                        textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }
}
