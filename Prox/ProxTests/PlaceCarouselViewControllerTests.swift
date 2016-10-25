/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
import CoreLocation
import MapKit

@testable import Prox

class PlaceCarouselViewControllerTests: XCTestCase {

    var placeCarouselVC: PlaceCarouselViewController!
    
    override func setUp() {
        super.setUp()
        placeCarouselVC = PlaceCarouselViewController()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testSortingByDistance() {
        let currentLocation = CLLocation(latitude: 51.5046323, longitude: -0.0992547)
        let place1 = Place(id: "1", name: "Place 1", summary: "Here is a summary of Place 1", latLong: CLLocationCoordinate2D(latitude: 51.5054704, longitude: -0.0943248))
        let place2 = Place(id: "2", name: "Place 2", summary: "Here is a summary of Place 2", latLong: CLLocationCoordinate2D(latitude: 51.5100773, longitude: -0.1257861))
        let place3 = Place(id: "3", name: "Place 3", summary: "Here is a summary of Place 3", latLong: CLLocationCoordinate2D(latitude: 51.4998605, longitude: -0.177838))
        let places = [place1, place2, place3]

        let sortedAscending = placeCarouselVC.sort(places: places, byDistanceFromLocation: currentLocation, ascending: true)
        XCTAssertNotNil(sortedAscending)
        XCTAssertEqual(sortedAscending[0].id, place1.id)
        XCTAssertEqual(sortedAscending[1].id, place2.id)
        XCTAssertEqual(sortedAscending[2].id, place3.id)

        let sortedDescending = placeCarouselVC.sort(places: places, byDistanceFromLocation: currentLocation, ascending: false)
        XCTAssertNotNil(sortedDescending)
        XCTAssertEqual(sortedDescending[0].id, place3.id)
        XCTAssertEqual(sortedDescending[1].id, place2.id)
        XCTAssertEqual(sortedDescending[2].id, place1.id)
    }

    func placesList(number: Int) -> [Place] {
        var places = [Place]()
        for index in 0..<number {
            let placeID = index + 1
            places.append(Place(id: "\(placeID)", name: "Place \(placeID)", summary: "Here is a summary of Place \(placeID)", latLong: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)))
        }

        return places
    }
    
}

// PlaceDataSource implementation tests
extension PlaceCarouselViewControllerTests {

    func testPlaceDataSourceReturnsCorrectNumberOfPlaces() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        XCTAssertEqual(placeCarouselVC.numberOfPlaces(), places.count)
    }

    func testPlaceDataSourceReturnsCorrectPlaceForIndex() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        let requestedIndex = 2

        let thirdPlace = try? placeCarouselVC.place(forIndex: requestedIndex)
        XCTAssertNotNil(thirdPlace)

        XCTAssertEqual(thirdPlace!.id, "\(requestedIndex + 1)")
    }

    func testPlaceDataSourceThrowsErrorOnOutOfBoundsIndex() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        XCTAssertThrowsError(try placeCarouselVC.place(forIndex: 4))
    }

    func testPlaceDataSourceReturnsCorrectNextPlace() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        // test with known next place
        var requestedIndex = 0
        var currentPlace = places[requestedIndex]
        // should be 1
        XCTAssertEqual(currentPlace.id, "\(requestedIndex + 1)")
        var nextPlace = placeCarouselVC.nextPlace(forPlace: currentPlace)
        // should be 2
        XCTAssertNotNil(nextPlace)
        XCTAssertEqual(nextPlace!.id, "\(requestedIndex + 2)")

        // test with known no next place
        requestedIndex = 3
        currentPlace = places[requestedIndex]
        nextPlace = placeCarouselVC.nextPlace(forPlace: currentPlace)
        XCTAssertNil(nextPlace)
    }

    func testPlaceDataSourceReturnsCorrectPreviousPlace() {
        let places = placesList(number: 4)
        placeCarouselVC.places = places

        // test with known next place
        var requestedIndex = 3
        var currentPlace = places[requestedIndex]
        // should be 4
        XCTAssertEqual(currentPlace.id, "\(requestedIndex + 1)")
        var previousPlace = placeCarouselVC.previousPlace(forPlace: currentPlace)
        XCTAssertNotNil(previousPlace)
        // should be 3
        XCTAssertEqual(previousPlace!.id, "\(requestedIndex)")

        // test with known no next place
        requestedIndex = 0
        currentPlace = places[requestedIndex]
        previousPlace = placeCarouselVC.previousPlace(forPlace: currentPlace)
        XCTAssertNil(previousPlace)
    }

}
