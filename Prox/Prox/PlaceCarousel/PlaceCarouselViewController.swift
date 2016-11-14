/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore
import EDSunriseSet
import Deferred

private let MAP_SPAN_DELTA = 0.05
private let MAP_LATITUDE_OFFSET = 0.015

private let ONE_DAY: TimeInterval = (60 * 60) * 24


protocol PlaceDataSource: class {
    func nextPlace(forPlace place: Place) -> Place?
    func previousPlace(forPlace place: Place) -> Place?
    func numberOfPlaces() -> Int
    func place(forIndex: Int) throws -> Place
}

protocol LocationProvider: class {
    func getCurrentLocation() -> CLLocation?
}

struct PlaceDataSourceError: Error {
    let message: String
}

class PlaceCarouselViewController: UIViewController {

    fileprivate let currentLocationIdentifier = "CURRENT_LOCATION"
    fileprivate let MIN_SECS_BETWEEN_LOCATION_UPDATES: TimeInterval = 1

    fileprivate var timeOfLastLocationUpdate: Date? {
        get {
            return UserDefaults.standard.value(forKey: AppConstants.timeOfLastLocationUpdateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.timeOfLastLocationUpdateKey)
        }
    }

    lazy var eventNotificationsManager: EventNotificationsManager = EventNotificationsManager()

    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // TODO: update to a more sane distance value when testing is over.
        // This is probably going to be around 100m
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = true
        return manager
    }()

    lazy var placesController: PlacesController = {
        let controller = PlacesController()
        controller.delegate = self
        return controller
    }()

    var places: [Place] = [Place]() {
        didSet {
            if oldValue == places {
                return
            }
            // TODO: how do we make sure the user wasn't interacting?
            headerView.numberOfPlacesLabel.text = "\(places.count) place" + (places.count != 1 ? "s" : "")
            placeCarousel.refresh()

            if oldValue.count == 0 {
                openClosestPlace()
            }
        }
    }

    // the top part of the background. Contains Number of Places, horizontal line & (soon to be) Current Location button
    lazy var headerView: PlaceCarouselHeaderView = {
        let view = PlaceCarouselHeaderView()
        view.backgroundColor = Colors.carouselViewHeaderBackground
        return view
    }()

    // View that will display the sunset and sunrise times
    lazy var sunView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewHeaderBackground

        view.layer.shadowColor = UIColor.darkGray.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 2

        return view
    }()

    // label displaying sunrise and sunset times
    lazy var sunriseSetTimesLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewSunriseSetTimesLabelText
        label.font = Fonts.carouselViewSunriseSetTimes
        return label
    }()

    lazy var placeCarousel: PlaceCarousel = {
        let carousel = PlaceCarousel()
        carousel.delegate = self
        carousel.dataSource = self
        carousel.locationProvider = self
        return carousel
    }()

    var sunriseSet: EDSunriseSet? {
        didSet {
            setSunriseSetTimes()
        }
    }

    // fake the location to Hilton Waikaloa Village, Kona, Hawaii
    fileprivate var fakeLocation: CLLocation = CLLocation(latitude: 19.924043, longitude: -155.887652)

    fileprivate var monitoredRegions: [String: GeofenceRegion] = [String: GeofenceRegion]()
    fileprivate var timeAtLocationTimer: Timer?

    private func setSunriseSetTimes() {
        let today = Date()

        guard let sunriseSet = self.sunriseSet else {
            return self.sunriseSetTimesLabel.text = nil
        }

        sunriseSet.calculateSunriseSunset(today)

        guard let sunrise = sunriseSet.localSunrise(),
            let sunset = sunriseSet.localSunset(),
            let calendar = NSCalendar(identifier: NSCalendar.Identifier.gregorian) else {
                return self.sunriseSetTimesLabel.text = nil
        }

        let sunriseToday = updateDateComponents(dateComponents: sunrise, toDate: today, withCalendar: calendar)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"

        if let sunriseTime = calendar.date(from: sunriseToday),
            sunriseTime > today {
            let timeAsString = dateFormatter.string(from: sunriseTime)
            return self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) today"
        }

        let sunsetToday = updateDateComponents(dateComponents: sunset, toDate: today, withCalendar: calendar)

        if let sunsetTime = calendar.date(from: sunsetToday),
            sunsetTime > today {
            let timeAsString = dateFormatter.string(from: sunsetTime)
            return self.sunriseSetTimesLabel.text = "Sunset is at \(timeAsString) today"
        }

        let tomorrow = today.addingTimeInterval(ONE_DAY)
        sunriseSet.calculateSunriseSunset(tomorrow)
        if let tomorrowSunrise = sunriseSet.localSunrise(),
            let tomorrowSunriseTime = calendar.date(from: tomorrowSunrise) {
            let timeAsString = dateFormatter.string(from: tomorrowSunriseTime)
            self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) tomorrow"
        } else {
            self.sunriseSetTimesLabel.text = nil
        }
    }

    private func updateDateComponents(dateComponents: DateComponents, toDate date: Date, withCalendar calendar: NSCalendar) -> DateComponents {
        var newDateComponents = dateComponents
        newDateComponents.day = calendar.component(NSCalendar.Unit.day, from: date)
        newDateComponents.month = calendar.component(NSCalendar.Unit.month, from: date)
        newDateComponents.year = calendar.component(NSCalendar.Unit.year, from: date)

        return newDateComponents
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let backgroundImage = UIImage(named: "map_background") {
            self.view.layer.contents = backgroundImage.cgImage
        }

        // add the views to the stack view
        view.addSubview(headerView)

        // setting up the layout constraints
        var constraints = [headerView.topAnchor.constraint(equalTo: view.topAnchor),
                           headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           headerView.heightAnchor.constraint(equalToConstant: 150)]

        view.addSubview(sunView)
        constraints.append(contentsOf: [sunView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
                                        sunView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        sunView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        sunView.heightAnchor.constraint(equalToConstant: 90)])


        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunriseSetTimesLabel)
        constraints.append(sunriseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunriseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        headerView.numberOfPlacesLabel.text = "" // placeholder

        view.addSubview(placeCarousel.carousel)
        constraints.append(contentsOf: [placeCarousel.carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        placeCarousel.carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        placeCarousel.carousel.topAnchor.constraint(equalTo: sunView.bottomAnchor, constant: -35),
                                        placeCarousel.carousel.heightAnchor.constraint(equalToConstant: 275)])

        // apply the constraints
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let location = getCurrentLocation() else {
            return
        }

        // this will update places when we first load, and whenever we show the place carousel
        // but not update places while we are showing details, until we close the place details
        // this ensures consistency between the place details and the carousel underneath
        // and makes sure we don't end up providing weird data to users while they are scrolling
        // through places details
        // if sunrise set is not present, then we haven't processed our first location yet, so setup the app for the current location
        // otherwise just update the places
        guard let _ = sunriseSet else {
            return self.updateLocation(location: location)
        }
        updatePlaces(forLocation: location)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func openClosestPlace() {
        guard places.count > 0 else {
            return
        }
        openDetail(forPlace: places[0])
    }

    func openDetail(forPlace place: Place) {
        // if we are already displaying a place detail, don't try and display another one
        // places should be able to update beneath without affecting what the user currently sees
        if let _ = self.presentedViewController {
            return
        }
        let placeDetailViewController = PlaceDetailViewController(place: place)
        placeDetailViewController.dataSource = self
        placeDetailViewController.locationProvider = self

        self.present(placeDetailViewController, animated: true, completion: nil)
    }

    // MARK: Location Handling

    func refreshLocation() {
        if (CLLocationManager.hasLocationPermissionAndEnabled()) {
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            // requestLocation expected to be called on authorization status change.
            locationManager.maybeRequestLocationPermission(viewController: self)
        }
    }

    func cancelTimeAtLocationTimer() {
        timeAtLocationTimer?.invalidate()
        timeAtLocationTimer = nil
    }

    func startTimeAtLocationTimer() {
        if timeAtLocationTimer == nil {
            timeAtLocationTimer = Timer.scheduledTimer(timeInterval: AppConstants.minimumIntervalAtLocationBeforeFetchingEvents, target: self, selector: #selector(timerFired(timer:)), userInfo: nil, repeats: true)
        }
    }

    @objc fileprivate func timerFired(timer: Timer) {
        guard let currentLocation = getCurrentLocation() else { return }
        eventNotificationsManager.fetchEvents(forLocation: currentLocation) { (events, error) in
            print("events have been fetched \(events), \(error)")
        }
    }

    fileprivate func updateLocation(location: CLLocation) {
        startTimeAtLocationTimer()
        startMonitoring(location: location, withIdentifier: currentLocationIdentifier, withRadius: AppConstants.currentLocationMonitoringRadius, forEntry: nil, forExit: {
            self.cancelTimeAtLocationTimer()
            self.stopMonitoringRegion(withIdentifier: self.currentLocationIdentifier)
        })
        updatePlaces(forLocation: location)
        updateSunRiseSetTimes(forLocation: location)
    }

    fileprivate func updatePlaces(forLocation location: CLLocation) {
        self.placesController.updatePlaces(forLocation: location)
    }

    fileprivate func updateSunRiseSetTimes(forLocation location: CLLocation) {
        let coord = location.coordinate
        // if we're running in the simulator, find the timezone of the current coordinates and calculate the sunrise/set times for then
        // this is so that, if we're simulating our location, we still get sunset/sunrise times
        #if (arch(i386) || arch(x86_64))
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async() {
                        self.sunriseSet = EDSunriseSet(timezone: placemark.timeZone, latitude: coord.latitude, longitude: coord.longitude)
                    }
                }
            }
        #else
            sunriseSet = EDSunriseSet(timezone: NSTimeZone.local, latitude: coord.latitude, longitude: coord.longitude)
        #endif

    }

    fileprivate func startMonitoring(location: CLLocation, withIdentifier identifier: String, withRadius radius: CLLocationDistance, forEntry: (()->())?, forExit: (()->())?) {
        let region = GeofenceRegion(location: location.coordinate, identifier: identifier, radius: radius, onEntry: forEntry, onExit: forExit)
        monitoredRegions[identifier] = region

        self.locationManager.startMonitoring(for: region.region)
    }

    fileprivate func stopMonitoringRegion(withIdentifier identifier: String) {
        guard let monitoredRegion = monitoredRegions[identifier]?.region else {
            return
        }
        self.locationManager.stopMonitoring(for: monitoredRegion)
        monitoredRegions.removeValue(forKey: identifier)
    }


    // MARK: Events
}

extension PlaceCarouselViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        refreshLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use last coord: we want to display where the user is now.
        if var location = locations.last {
            // In iOS9, didUpdateLocations can be unexpectedly called multiple
            // times for a single `requestLocation`: we guard against that here.
            if timeOfLastLocationUpdate == nil ||
                (location.timestamp - MIN_SECS_BETWEEN_LOCATION_UPDATES) > timeOfLastLocationUpdate! {

                if AppConstants.MOZ_LOCATION_FAKING {
                    // fake the location to Hilton Waikaloa Village, Kona, Hawaii
                    location = fakeLocation
                }

                // only update places if this is our first location update
                if timeOfLastLocationUpdate == nil {
                    updateLocation(location: location)
                }
                timeOfLastLocationUpdate = location.timestamp
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: handle
        print("lol-location \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        monitoredRegions[region.identifier]?.onEntry?()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        monitoredRegions[region.identifier]?.onExit?()
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("lol-location region monitoring failed \(error.localizedDescription)")
    }
}

extension PlaceCarouselViewController: PlaceDataSource {

    func nextPlace(forPlace place: Place) -> Place? {
        guard let currentPlaceIndex = places.index(where: {$0 == place}),
            currentPlaceIndex + 1 < places.endIndex else {
                return nil
        }

        return places[places.index(after: currentPlaceIndex)]
    }

    func previousPlace(forPlace place: Place) -> Place? {
        guard let currentPlaceIndex = places.index(where: {$0 == place}),
            currentPlaceIndex > places.startIndex else {
                return nil
        }

        return places[places.index(before: currentPlaceIndex)]
    }

    func numberOfPlaces() -> Int {
        return places.count
    }

    func place(forIndex index: Int) throws -> Place {
        guard index < places.endIndex,
            index >= places.startIndex else {
            throw PlaceDataSourceError(message: "There is no place at index: \(index)")
        }

        return places[index]
    }
}

extension PlaceCarouselViewController: PlaceCarouselDelegate {
    func placeCarousel(placeCarousel: PlaceCarousel, didSelectPlaceAtIndex index: Int) {
        openDetail(forPlace: places[index])
    }
}

extension PlaceCarouselViewController: LocationProvider {
    func getCurrentLocation() -> CLLocation? {
        guard AppConstants.MOZ_LOCATION_FAKING else {
            return self.locationManager.location
        }
        // fake the location to Hilton Waikaloa Village, Kona, Hawaii
        return fakeLocation
    }
}

extension PlaceCarouselViewController: EventsControllerDelegate {
    func eventController(_ eventController: EventsController, didError error: Error) {

    }

    func eventController(_ eventController: EventsController, didUpdateEvents: [Event]) {
    }
}

extension PlaceCarouselViewController: PlacesControllerDelegate {
    func placeControllerWillStartFetchingPlaces(_ controller: PlacesController) {
        // TODO placeholder for the waiting state.
        if self.places.count == 0 {
            headerView.numberOfPlacesLabel.text = "Waiting"
        }
    }

    func placeControllerDidFinishFetchingPlaces(_ controller: PlacesController) {
        // no op
    }

    func placesController(_ controller: PlacesController, didReceivePlaces places: [Place]) {
        self.places = places
    }

    func placesController(_ controller: PlacesController, didError error: Error) {
        if self.places.count == 0 {
            // placeholder for the error state.
            headerView.numberOfPlacesLabel.text = "Error"
        }
    }
}

