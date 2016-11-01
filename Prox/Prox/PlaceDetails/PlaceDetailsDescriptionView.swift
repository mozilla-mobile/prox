/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class PlaceDetailsDescriptionView: HorizontalLineView {

    let horizontalMargin: CGFloat

    lazy var logoView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var label: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionText
        return view
    }()

    // TODO: icon
    // TODO: how to expand?
    lazy var expandButton: UIImageView = UIImageView()

    init(labelText: String,
         icon: UIImage?, // TODO: non-optional
         horizontalMargin: CGFloat) {
        self.horizontalMargin = horizontalMargin
        super.init(frame: .zero)
        logoView.image = icon
        label.text = labelText
        backgroundColor = .clear

        setupSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(logoView)
        var constraints = [logoView.topAnchor.constraint(equalTo: topAnchor),
                           logoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalMargin),
                           logoView.widthAnchor.constraint(equalToConstant: 16),
                           logoView.bottomAnchor.constraint(equalTo: bottomAnchor)]

        addSubview(label)
        constraints += [label.topAnchor.constraint(equalTo: logoView.topAnchor),
                        label.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: horizontalMargin),
                        label.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -horizontalMargin),
                        label.bottomAnchor.constraint(equalTo: logoView.bottomAnchor)]

        addSubview(expandButton)
        constraints += [expandButton.topAnchor.constraint(equalTo: logoView.topAnchor),
                        expandButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalMargin),
                        expandButton.widthAnchor.constraint(equalToConstant: 16),
                        expandButton.bottomAnchor.constraint(equalTo: logoView.bottomAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLine()
    }

    private func setupLine() {
        color = Colors.detailsViewCardSeparator
        startX = bounds.minX
        endX = bounds.maxX
        startY = bounds.minY
        endY = bounds.minY
    }
}
