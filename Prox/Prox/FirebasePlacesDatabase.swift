/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Firebase

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
    func getPlaces(forLocation location: CLLocation, withBlock callback: @escaping ([Place]) -> Void) {
        getPlaceKeys(aroundPoint: location) { placeKeyToLoc in
            self.getPlaceDetails(fromKeys: Array(placeKeyToLoc.keys)) { places in
                print("lol got place details: \(places)")
                callback(places)
            }
        }
    }

    /*
     * Queries GeoFire to find keys that represent locations around the given point.
     */
    private func getPlaceKeys(aroundPoint location: CLLocation,
                              withBlock callback: @escaping ([String:CLLocation]) -> Void) {
        var placeKeyToLoc = [String:CLLocation]()
        guard let circleQuery = geofire.query(at: location, withRadius: SEARCH_RADIUS_KM) else {
            // TODO: is this properly handling the else case?
            callback(placeKeyToLoc)
            return
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
            callback(placeKeyToLoc)
        }
    }

    /*
     * Queries Firebase to find the place details from the given keys.
     */
    private func getPlaceDetails(fromKeys placeKeys: [String],
                                 withBlock callback: @escaping ([Place]) -> Void) {
        var places = [Place]()
        // TODO: how can we query on multiple child keys?
        guard let first = placeKeys.first else {
            callback(places)
            return
        }

        let childRef = placeDetailsRef.child(first)
        childRef.queryOrderedByKey().observeSingleEvent(of: .value) { (data: FIRDataSnapshot) in
            if let place = Place(fromFirebaseSnapshot: data) {
                places.append(place)
            } else {
                print("lol Failed to handle data: \(data)")
            }
            callback(places)
        }
    }
}
