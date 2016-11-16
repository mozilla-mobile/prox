/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase
import Deferred
import CoreLocation

// Adding "$name/" allows you to develop against a locally run database.
// TODO prox-server – allow this string to be passed in as a URL parameter when in debug mode. 
private let ROOT_PATH = ""
private let VENUES_PATH = ROOT_PATH + "venues/"
private let GEOFIRE_PATH = VENUES_PATH + "locations/"
private let DETAILS_PATH = VENUES_PATH + "details/"

class FirebasePlacesDatabase: PlacesDatabase {

    private let placeDetailsRef: FIRDatabaseReference
    private let geofire: GeoFire

    init() {
        let rootRef = FIRDatabase.database().reference()
        placeDetailsRef = rootRef.child(DETAILS_PATH)
        geofire = GeoFire(firebaseRef: rootRef.child(GEOFIRE_PATH))
    }

    /*
     * Queries GeoFire to get the place keys around the given location and then queries Firebase to
     * get the place details for the place keys.
     */
    func getPlaces(forLocation location: CLLocation, withRadius radius: Double) -> Future<[DatabaseResult<Place>]> {
        let queue = DispatchQueue.global(qos: .userInitiated)
        let places = getPlaceKeys(aroundPoint: location, withRadius: radius).andThen(upon: queue) { (placeKeyToLoc) -> Future<[DatabaseResult<Place>]> in
            // TODO: limit the number of place details we look up. X closest places?
            // TODO: These should be ordered by display order
            return self.getPlaceDetails(fromKeys: Array(placeKeyToLoc.keys)).allFilled()
        }
        return places
    }

    /*
     * Queries GeoFire to find keys that represent locations around the given point.
     */
    private func getPlaceKeys(aroundPoint location: CLLocation, withRadius radius: Double) -> Deferred<[String:CLLocation]> {
        let deferred = Deferred<[String:CLLocation]>()
        var placeKeyToLoc = [String:CLLocation]()

        guard let circleQuery = geofire.query(at: location, withRadius: radius) else {
            deferred.fill(with: placeKeyToLoc)
            return deferred
        }

        // Append results to return object.
        circleQuery.observe(.keyEntered) { (key, location) in
            if let unwrappedKey = key, let unwrappedLocation = location {
                placeKeyToLoc[unwrappedKey] = unwrappedLocation
            }
        }

        // Handle query completion.
        circleQuery.observeReady {
            print("lol geofire query has completed")
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
            guard data.exists() else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Child place key does not exist: \(placeKey)"))
                return
            }

            if let place = Place(fromFirebaseSnapshot: data) {
                deferred.fill(with: DatabaseResult.succeed(value: place))
            } else {
                deferred.fill(with: DatabaseResult.fail(withMessage: "Snapshot missing required Place data: \(data)"))
            }
        }

        return deferred
    }

    func getPlace(forKey key: String) -> Deferred<DatabaseResult<Place>> {
        return queryChildPlaceDetails(by: key)
    }
}
