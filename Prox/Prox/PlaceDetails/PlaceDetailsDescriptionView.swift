/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

fileprivate enum UIMode {
    case collapsed, expanded
}

class PlaceDetailsDescriptionView: HorizontalLineView {

    private let CollapseExpandSeconds = 1.0

    let horizontalMargin: CGFloat

    fileprivate var uiMode: UIMode = .collapsed
    var collapsedConstraints: [NSLayoutConstraint]!
    var expandedConstraints: [NSLayoutConstraint]!

    lazy var logoView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var label: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionTitle
        return view
    }()

    // TODO: icon
    lazy var expandButton: UIImageView = UIImageView()

    lazy var expandableLabel: UILabel = {
        let view = UILabel()
        view.font = Fonts.detailsViewDescriptionText
        view.textColor = Colors.detailsViewCardSecondaryText
        view.numberOfLines = 0
        return view
    }()

    init(labelText: String,
         icon: UIImage?, // TODO: non-optional
         horizontalMargin: CGFloat) {
        self.horizontalMargin = horizontalMargin
        super.init(frame: .zero)

        logoView.image = icon
        label.text = labelText
        backgroundColor = .clear

        setupSubviews()
        setupGestureRecognizer()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGestureRecognizer() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(gestureRecognizer)
    }

    private func setupSubviews() {
        addSubview(logoView)
        var constraints = [logoView.topAnchor.constraint(equalTo: topAnchor),
                           logoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalMargin),
                           logoView.widthAnchor.constraint(equalToConstant: 16),
                           logoView.bottomAnchor.constraint(equalTo: label.bottomAnchor)]

        addSubview(label)
        constraints += [label.topAnchor.constraint(equalTo: logoView.topAnchor),
                        label.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: horizontalMargin),
                        label.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -horizontalMargin),
                        label.heightAnchor.constraint(equalToConstant: 56)]

        addSubview(expandButton)
        constraints += [expandButton.topAnchor.constraint(equalTo: logoView.topAnchor),
                        expandButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalMargin),
                        expandButton.widthAnchor.constraint(equalToConstant: 16),
                        expandButton.bottomAnchor.constraint(equalTo: logoView.bottomAnchor)]

        collapsedConstraints = [bottomAnchor.constraint(equalTo: label.bottomAnchor)]
        constraints += collapsedConstraints

        expandedConstraints = getExpandedConstraints()

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    private func getExpandedConstraints() -> [NSLayoutConstraint] {
        return [expandableLabel.topAnchor.constraint(equalTo: label.bottomAnchor),
                expandableLabel.leadingAnchor.constraint(equalTo: logoView.leadingAnchor),
                expandableLabel.trailingAnchor.constraint(equalTo: expandButton.trailingAnchor),
                bottomAnchor.constraint(equalTo: expandableLabel.bottomAnchor)]
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
        endY = bounds.minY // TODO: divide by pixel scaling to ensure 1px
    }

    @objc private func didTap() {
        switch uiMode {
        case .collapsed:
            uiMode = .expanded
            expandView()
        case .expanded:
            uiMode = .collapsed
            collapseView()
        }
    }

    private func expandView() {
        layoutIfNeeded()

        NSLayoutConstraint.deactivate(collapsedConstraints)
        addSubview(expandableLabel)
        NSLayoutConstraint.activate(expandedConstraints, translatesAutoresizingMaskIntoConstraints: false)
        self.layoutIfNeeded()
    }

    private func collapseView() {
        layoutIfNeeded()

        expandableLabel.removeFromSuperview()
        NSLayoutConstraint.deactivate(expandedConstraints)
        NSLayoutConstraint.activate(collapsedConstraints)
        self.layoutIfNeeded()
    }
}
