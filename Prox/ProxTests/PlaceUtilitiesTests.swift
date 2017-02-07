/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
import CoreLocation

@testable import Prox

class PlaceUtilitiesTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    


    func testSortingByDistance() {
        // Mozilla London Office
        let currentLocation = CLLocation(latitude: 51.5046323, longitude: -0.0992547)

        let yelpProvider = SourcePlaceProvider(fromDictionary: [:])
        // London Bridge Station

        let emptyCategories = (names: [""], ids: [""])
        let place1 = Place(id: "1", name: "Place 1", latLong: CLLocationCoordinate2D(latitude: 51.5054704, longitude: -0.0943248), categories: emptyCategories, yelpProvider: yelpProvider)
        // old Mozilla London office
        let place2 = Place(id: "2", name: "Place 2", latLong: CLLocationCoordinate2D(latitude: 51.5100773, longitude: -0.1257861), categories: emptyCategories, yelpProvider: yelpProvider)
        // Kensington Palace
        let place3 = Place(id: "3", name: "Place 3", latLong: CLLocationCoordinate2D(latitude: 51.4998605, longitude: -0.177838), categories: emptyCategories, yelpProvider: yelpProvider)
        let places = [place1, place2, place3]

        let sortedAscending = PlaceUtilities.sort(places: places, byDistanceFromLocation: currentLocation, ascending: true)
        XCTAssertNotNil(sortedAscending)
        XCTAssertEqual(sortedAscending[0].id, place1.id)
        XCTAssertEqual(sortedAscending[1].id, place2.id)
        XCTAssertEqual(sortedAscending[2].id, place3.id)

        let sortedDescending = PlaceUtilities.sort(places: places, byDistanceFromLocation: currentLocation, ascending: false)
        XCTAssertNotNil(sortedDescending)
        XCTAssertEqual(sortedDescending[0].id, place3.id)
        XCTAssertEqual(sortedDescending[1].id, place2.id)
        XCTAssertEqual(sortedDescending[2].id, place1.id)
    }

    /*
     * This logic can change a lot so it's not worth writing comprehensive tests for, I think.
     * This is more of a sanity check.
     */
    func testShouldShowPlaceByRatingAndReviewCount() {
        let lowRatingLowReviewPlace = getPlace(forRating: 1.0, reviewCount: 3)
        XCTAssertFalse(PlaceUtilities.shouldShowPlaceByRatingAndReviewCount(lowRatingLowReviewPlace))

        let highRatingHighReviewPlace = getPlace(forRating: 5.0, reviewCount: 3634)
        XCTAssertTrue(PlaceUtilities.shouldShowPlaceByRatingAndReviewCount(highRatingHighReviewPlace))
    }

    private func getPlace(forRating rating: Float, reviewCount: Int) -> Place {
        let yelpProvider = SourcePlaceProvider(fromDictionary: ["rating": rating, "totalReviewCount": reviewCount])
        return Place(id: "id", name: "name", latLong: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                     categories: ([], []), yelpProvider: yelpProvider)
    }
    
}
