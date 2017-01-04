/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Prox
import CoreLocation
import MapKit
import Deferred

class TravelTimesTests: XCTestCase {

    let timeout = 30.0

    let testSource = CLLocationCoordinate2D(latitude: 51.5046323, longitude: -0.0992547)
    let testDestination = CLLocationCoordinate2D(latitude: 51.5100773, longitude: -0.1257861)

    let travelTimesProviders: [TravelTimesProvider.Type] = [MKDirectionsTravelTimesProvider.self, GoogleDirectionsMatrixTravelTimesProvider.self]

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testAnyTravelTimes() {
        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")
            provider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: MKDirectionsTransportType.any) { travelTimes in
                XCTAssertNotNil(travelTimes)
                XCTAssertTrue(travelTimes?.walkingTime != nil || travelTimes?.drivingTime != nil || travelTimes?.publicTransportTime != nil)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }

    }

    func testWalkingTravelTimes() {
        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .walking) { travelTimes in
                XCTAssertNotNil(travelTimes)
                XCTAssertNotNil(travelTimes?.walkingTime)
                XCTAssertNil(travelTimes?.drivingTime)
                XCTAssertNil(travelTimes?.publicTransportTime)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
        
    }

    func testAutomobileTravelTimes() {
        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .automobile) { travelTimes in
                XCTAssertNotNil(travelTimes)
                XCTAssertNil(travelTimes?.walkingTime)
                XCTAssertNotNil(travelTimes?.drivingTime)
                XCTAssertNil(travelTimes?.publicTransportTime)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
        
    }

    func testPublicTransportTravelTimes() {

        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitType: .transit) { travelTimes in
                XCTAssertNotNil(travelTimes)
                XCTAssertNil(travelTimes?.walkingTime)
                XCTAssertNil(travelTimes?.drivingTime)
                XCTAssertNotNil(travelTimes?.publicTransportTime)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
        
    }

    func testInvalidRoute() {
        let testInvalidDestination = CLLocationCoordinate2D(latitude: 19.9542305, longitude: 155.8531072)

        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testInvalidDestination, byTransitType: MKDirectionsTransportType.any) { travelTimes in
                XCTAssertNil(travelTimes)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
    }

    func testMultipleTravelTypes() {
        let travelRoutes = [MKDirectionsTransportType.automobile, MKDirectionsTransportType.walking]

        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testDestination, byTransitTypes: travelRoutes) { travelTimes in

                XCTAssertNotNil(travelTimes)
                XCTAssertNotNil(travelTimes?.walkingTime)
                XCTAssertNotNil(travelTimes?.drivingTime)
                XCTAssertNil(travelTimes?.publicTransportTime)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
    }

    func testMultipleTravelTypesInvalidRoute() {
        let travelRoutes = [MKDirectionsTransportType.automobile, MKDirectionsTransportType.walking]
        let testInvalidDestination = CLLocationCoordinate2D(latitude: 19.9542305, longitude: 155.8531072)

        for provider in travelTimesProviders {
            let waitQuery = expectation(description: "Waiting for travel times by \(provider) to be calculated")

            provider.travelTime(fromLocation: testSource, toLocation: testInvalidDestination, byTransitTypes: travelRoutes) { travelTimes in
                XCTAssertNil(travelTimes)
                waitQuery.fulfill()
            }

            waitForExpectations(timeout: timeout)
        }
    }

}
