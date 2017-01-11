/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

fileprivate let LOCATION_NAME_TO_COORD: [(name: String, lat: Double, lng: Double)] = [
        ("Garfield Park Conservatory Chicago", 41.886724, -87.717264), // https://www.yelp.com/biz/garfield-park-conservatory-chicago
        ("Museum of Science and Industry", 41.790805, -87.583130), // https://www.yelp.com/biz/museum-of-science-and-industry-chicago-3
        ("Chicago Cultural Center", 41.883754, -87.624941), // https://www.yelp.com/biz/chicago-cultural-center-chicago
        ("Metropolis Coffee Company", 41.994339, -87.657278), // https://www.yelp.com/biz/metropolis-coffee-company-chicago-3
        ]

fileprivate let REUSE_ID = "I'M FAKING IT"

class MockLocationSelectionTableViewController: UITableViewController {

    weak var nextViewController: UIViewController?
    weak var locationMonitor: LocationMonitor?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Offset tableView items so they don't appear under status bar. This appears to be an Apple bug:
        // http://stackoverflow.com/a/18951786/2219998 I opted for the simpler solution to save time:
        // http://stackoverflow.com/a/19424577/2219998
        tableView.contentInset = UIEdgeInsets(top: UIApplication.shared.statusBarFrame.height, left: 0, bottom: 0, right: 0)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: REUSE_ID)

        let constraints = [tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
                           tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           tableView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor)]
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return LOCATION_NAME_TO_COORD.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: REUSE_ID, for: indexPath)

        let (name, _, _) = LOCATION_NAME_TO_COORD[indexPath.row]
        cell.textLabel?.text = name

        return cell
    }

    // MARK: Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let (_, lat, lng) = LOCATION_NAME_TO_COORD[indexPath.row]
        locationMonitor?.fakeLocation = CLLocation(latitude: lat, longitude: lng)
        locationMonitor?.refreshLocation()
        present(nextViewController!, animated: true)
    }
}
