/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceDetailsIconInfoView: UIView {

    lazy var iconView: UIImageView = {
        let view = UIImageView()
        // TODO: view.contentMode (scaling)
        return view
    }()

    // Contains the labels, providing an anchor on the widest text for the icon.
    lazy var labelContainer: UIView = UIView()

    // TODO: line count & truncation
    lazy var primaryTextLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardPrimaryText
        view.font = Fonts.detailsViewIconInfoPrimaryText
        view.textAlignment = .center
        return view
    }()

    lazy var secondaryTextLabel: UILabel = {
        let view = UILabel()
        view.textColor = Colors.detailsViewCardSecondaryText
        view.font = Fonts.detailsViewIconInfoSecondaryText
        view.textAlignment = .center
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        var constraints = setupLabelContainerSubviews()
        addSubview(labelContainer)
        constraints += [labelContainer.topAnchor.constraint(equalTo: topAnchor),
                        labelContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
                        labelContainer.bottomAnchor.constraint(equalTo: bottomAnchor)]

        addSubview(iconView)
        constraints += [iconView.centerYAnchor.constraint(equalTo: labelContainer.centerYAnchor),
                        iconView.trailingAnchor.constraint(equalTo: labelContainer.leadingAnchor, constant: -9)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func setupLabelContainerSubviews() -> [NSLayoutConstraint] {
        labelContainer.addSubview(primaryTextLabel)
        var constraints = [primaryTextLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor),
                           primaryTextLabel.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor),
                           primaryTextLabel.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor),
                           primaryTextLabel.heightAnchor.constraint(equalTo: labelContainer.heightAnchor, multiplier: 0.5)]

        labelContainer.addSubview(secondaryTextLabel)
        constraints += [secondaryTextLabel.topAnchor.constraint(equalTo: primaryTextLabel.bottomAnchor),
                        secondaryTextLabel.leadingAnchor.constraint(equalTo: primaryTextLabel.leadingAnchor),
                        secondaryTextLabel.trailingAnchor.constraint(equalTo: primaryTextLabel.trailingAnchor),
                        secondaryTextLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor)]

        return constraints
    }
}
