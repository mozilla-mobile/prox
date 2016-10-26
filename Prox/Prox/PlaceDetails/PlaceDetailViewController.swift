/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceDetailViewController: UIViewController {

    private let place: Place
    weak var dataSource: PlaceDataSource?

    // TODO: make carousel
    lazy var headerImageView: UIImageView = {
        let image = UIImage(named: "place-placeholder") // TODO: placeholder
        let view = UIImageView(image: image)
        return view
    }()

    lazy var cardView: PlaceDetailsCardView = {
        let view = PlaceDetailsCardView()
        return view
    }()

    init(place: Place) {
        self.place = place
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0.5, alpha: 1) // TODO: blurred image background

        view.addSubview(headerImageView)
        var constraints = [headerImageView.topAnchor.constraint(equalTo: view.topAnchor),
                           headerImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           headerImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           headerImageView.heightAnchor.constraint(equalToConstant: 240)]

        view.addSubview(cardView)
        constraints += [cardView.topAnchor.constraint(equalTo: view.topAnchor, constant: 204),
                        cardView.widthAnchor.constraint(equalToConstant: 343),
                        cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
