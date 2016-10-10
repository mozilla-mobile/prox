/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore

class PlaceCarouselViewController: UIViewController {

    // All views in the background are going to be displayed using a stack view
    lazy var baseView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.distribution = UIStackViewDistribution.fillProportionally
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // the top part of the background. Contains Number of Places, horizontal line & (soon to be) Current Location button
    lazy var headerView: PlaceCarouselHeaderView = {
        let view = PlaceCarouselHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // View that will display the sunset and sunrise times
    lazy var sunView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white

        // this is adding a drop shadow to the view. 
        // note: Doesn't seem to be working in stack view
        view.clipsToBounds = false;
        view.layer.shadowColor = UIColor.black.cgColor;
        view.layer.shadowOffset = CGSize(width: 0, height: 5);
        view.layer.shadowOpacity = 0.5;

        return view
    }()

    // the map view
    lazy var mapView: MKMapView = {
        let view = MKMapView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // label displaying sunrise and sunset times
    lazy var sunRiseSetTimesLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(colorLiteralRed: 0.64, green: 0.64, blue: 0.64, alpha: 1.0)
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // add the views to the stack view
        view.addSubview(baseView)
        baseView.addArrangedSubview(headerView)
        baseView.addArrangedSubview(sunView)
        baseView.addArrangedSubview(mapView)

        // setting up the layout constraints
        var constraints = [baseView.topAnchor.constraint(equalTo: view.topAnchor),
                           baseView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           baseView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                           baseView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           headerView.heightAnchor.constraint(equalToConstant: 150),
                           sunView.heightAnchor.constraint(equalToConstant: 90),
                           mapView.heightAnchor.constraint(equalToConstant: 400)]


        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunRiseSetTimesLabel)
        constraints.append(sunRiseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunRiseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        // placeholder text for the labels
        headerView.numberOfPlacesLabel.text = "4 places"
        sunRiseSetTimesLabel.text = "Sunset is at 6:14pm today"

        // apply the constraints
        NSLayoutConstraint.activate(constraints)


    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

