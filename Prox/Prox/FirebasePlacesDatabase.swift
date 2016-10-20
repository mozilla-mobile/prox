/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import Deferred
import CoreLocation

private let ROOT_PATH = "venues/"
private let GEOFIRE_PATH = ROOT_PATH + "locations/"
private let DETAILS_PATH = ROOT_PATH + "details/"

private let SEARCH_RADIUS_KM = 4.0 // TODO: set distance

let TEST_LL = CLLocation(latitude: 19.9263136, longitude: -155.8868328) // TODO: rm me!

class FirebasePlacesDatabase: PlacesDatabase {

    private let placeDetailsRef: FIRDatabaseReference
    private let geofire: GeoFire

    init() {
        let rootRef = FIRDatabase.database().reference()
        placeDetailsRef = rootRef.child(DETAILS_PATH)
        geofire = GeoFire(firebaseRef: rootRef.child(GEOFIRE_PATH))
    }

    // todo: handle errors (double-check every query)
    // TODO: handle version in DB
    /*
     * Queries GeoFire to get the place keys around the given location and then queries Firebase to
     * get the place details for the place keys.
     */
    func getPlaces(forLocation location: CLLocation) -> Future<[DatabaseResult<Place>]> {
        // TODO: OperationQueue.current okay?
        let places = getPlaceKeys(aroundPoint: location).andThen(upon: OperationQueue.current!) { (placeKeyToLoc) -> Future<[DatabaseResult<Place>]> in
            // TODO: limit the number of place details we look up. X closest places?
            // TODO: can we assume all queries will finish?
            // TODO: These should be ordered by display order
            return self.getPlaceDetails(fromKeys: Array(placeKeyToLoc.keys)).allFilled()
        }
        return places
    }

    /*
     * Queries GeoFire to find keys that represent locations around the given point.
     */
    private func getPlaceKeys(aroundPoint location: CLLocation) -> Deferred<[String:CLLocation]> {
        let deferred = Deferred<[String:CLLocation]>()
        var placeKeyToLoc = [String:CLLocation]()

        guard let circleQuery = geofire.query(at: location, withRadius: SEARCH_RADIUS_KM) else {
            // TODO: is this properly handling the else case?
            deferred.fill(with: placeKeyToLoc)
            return deferred
        }

        // Append results to return object.
        circleQuery.observe(.keyEntered) { (key, location) in
            // TODO: why is this optional value? handle.
            placeKeyToLoc[key!] = location!
        }

        // Handle query completion (TODO: does this actually indicate query completion?).
        circleQuery.observeReady {
            // TODO: test what happens when observe is never called (i.e. no results).
            print("lol All initial data has been loaded and events have been fired for circle query!")
            circleQuery.removeAllObservers()
            deferred.fill(with: placeKeyToLoc)
        }

        return deferred
    }

    /*
     * Queries Firebase to find the place details from the given keys.
     */
    private func getPlaceDetails(fromKeys placeKeys: [String]) -> [Deferred<DatabaseResult<Place>>] {
        let placeDetails = placeKeys.map { placeKey -> Deferred<DatabaseResult<Place>> in
            queryChildPlaceDetails(by: placeKey)
        }
        return placeDetails
    }

    private func queryChildPlaceDetails(by placeKey: String) -> Deferred<DatabaseResult<Place>> {
        let deferred = Deferred<DatabaseResult<Place>>()

        let childRef = placeDetailsRef.child(placeKey)
        childRef.queryOrderedByKey().observeSingleEvent(of: .value) { (data: FIRDataSnapshot) in
            if let place = Place(fromFirebaseSnapshot: data) {
                deferred.fill(with: DatabaseResult.succeed(value: place))
            } else {
                // TODO: make better than optional; handle correctly.
                // Note: I tried to return an optional here and the Deferred lib crashes.
                deferred.fill(with: DatabaseResult.fail(withMessage: "Unable to create place"))
            }
        }

        return deferred
    }
}
