/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class PlaceDetailsCardViewController: UIViewController {

    var place: Place!

    lazy var cardView: PlaceDetailsCardView = {
        let view = PlaceDetailsCardView()
        return view
    }()

    init(place: Place) {
        self.place = place
        super.init(nibName: nil, bundle: nil)

        setPlace(place: place)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        view.addSubview(cardView)

        let constraints = [cardView.topAnchor.constraint(equalTo: view.topAnchor),
                           cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor)]

        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // TODO: set the view values in cardView to values in place
    open func setPlace(place: Place) {
        print("setting place")
    }
}
