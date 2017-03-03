/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import AFNetworking
import Deferred
import FirebaseRemoteConfig
import Foundation

/*
 * Delegate methods for updating places asynchronously.
 * All methods on the delegate will be called on the main thread.
 */
protocol PlacesProviderDelegate: class {
    func placesProvider(_ controller: PlacesProvider, didUpdatePlaces places: [Place])
}

private let ratingWeight: Float = 1
private let reviewWeight: Float = 2

class PlacesProvider {
    weak var delegate: PlacesProviderDelegate?

    private let database = FirebasePlacesDatabase()

    private lazy var radius: Double = {
        return RemoteConfigKeys.searchRadiusInKm.value
    }()

    private var allPlaces = [Place]()

    private var displayedPlaces = [Place]()
    fileprivate var placeKeyMap = [String: Int]()

    /// Protects allPlaces, displayedPlaces, and placeKeyMap.
    fileprivate let placesLock = NSLock()

    private(set) var enabledFilters: Set<PlaceFilter> = Set([ .discover ])
    private(set) var topRatedOnly = false

    init() {}

    convenience init(places: [Place]) {
        self.init()
        self.displayedPlaces = places
        var placesMap = [String: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        self.placeKeyMap = placesMap
    }

    func place(forKey key: String, callback: @escaping (Place?) -> ()) {
        database.getPlace(forKey: key).upon { callback($0.successResult() )}
    }

    func updatePlaces(forLocation location: CLLocation) {
        // Fetch a stable list of places from firebase.
        database.getPlaces(forLocation: location, withRadius: radius).upon { results in
            let places = results.flatMap { $0.successResult() }
            self.displayPlaces(places: places, forLocation: location)
        }
    }

    func filterPlaces(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) -> [Place] {
        return placesLock.withReadLock {
            return filterPlacesLocked(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)
        }
    }

    /// Callers must acquire a read lock before calling this method!
    /// TODO: Terrible name, terrible pattern. Fix this with #529.
    private func filterPlacesLocked(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) -> [Place] {
        let distanceSortedPlaces = allPlaces.filter { place in
            let filter: PlaceFilter
            if place.id.hasPrefix(AppConstants.testPrefixDiscover) {
                filter = .discover
            } else {
                guard let firstFilter = place.categories.ids.flatMap({ CategoriesUtil.categoryToFilter[$0] }).first else { return false }
                filter = firstFilter
            }
            return enabledFilters.contains(filter)
        }

        guard topRatedOnly else { return distanceSortedPlaces }

        let maxReviews = distanceSortedPlaces.map { $0.totalReviewCount }.max() ?? 0
        let logMaxReviews = log10(Float(maxReviews))

        let sorted = distanceSortedPlaces.sorted { a, b in
            return proxRating(forPlace: a, logMaxReviews: logMaxReviews) > proxRating(forPlace: b, logMaxReviews: logMaxReviews)
        }

        return sorted
    }

    /// Returns a number from 0-1 that weighs different properties on the place.
    private func proxRating(forPlace place: Place, logMaxReviews: Float) -> Float {
        let yelpCount = Float(place.yelpProvider.totalReviewCount)
        let taCount = Float(place.tripAdvisorProvider?.totalReviewCount ?? 0)
        let yelpRating = place.yelpProvider.rating ?? 0
        let taRating = place.tripAdvisorProvider?.rating ?? 0
        let ratingScore = (yelpRating * yelpCount + taRating * taCount) / (yelpCount + taCount) / 5
        let reviewScore = log10(yelpCount + taCount) / logMaxReviews
        return (ratingScore * ratingWeight + reviewScore * reviewWeight) / (ratingWeight + reviewWeight)
    }

    /// Applies the current set of filters to all places, setting `displayedPlaces` to the result.
    /// Callers must acquire a write lock before calling this method!
    fileprivate func updateDisplayedPlaces() {
        displayedPlaces = filterPlacesLocked(enabledFilters: enabledFilters, topRatedOnly: topRatedOnly)

        var placesMap = [String: Int]()
        for (index, place) in displayedPlaces.enumerated() {
            placesMap[place.id] = index
        }
        placeKeyMap = placesMap
    }

    private func displayPlaces(places: [Place], forLocation location: CLLocation) {
        return PlaceUtilities.sort(places: places, byTravelTimeFromLocation: location, ascending: true, completion: { sortedPlaces in
            self.placesLock.withWriteLock {
                self.allPlaces = sortedPlaces
                self.updateDisplayedPlaces()
            }
            DispatchQueue.main.async {
                var displayedPlaces: [Place]!
                self.placesLock.withReadLock {
                    displayedPlaces = self.displayedPlaces
                }
                self.delegate?.placesProvider(self, didUpdatePlaces: displayedPlaces)
            }

        })
    }

    func nextPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            // if the place isn't in the list, make the first item in the list the next item
            guard let currentPlaceIndex = self.placeKeyMap[place.id] else {
                return displayedPlaces.count > 0 ? displayedPlaces[displayedPlaces.startIndex] : nil
            }

            guard currentPlaceIndex + 1 < displayedPlaces.endIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(after: currentPlaceIndex)]
        }
    }

    func previousPlace(forPlace place: Place) -> Place? {
        return self.placesLock.withReadLock {
            guard let currentPlaceIndex = self.placeKeyMap[place.id],
                currentPlaceIndex > displayedPlaces.startIndex else { return nil }

            return displayedPlaces[displayedPlaces.index(before: currentPlaceIndex)]
        }
    }

    func numberOfPlaces() -> Int {
        return self.placesLock.withReadLock {
            return displayedPlaces.count
        }
    }

    func place(forIndex index: Int) throws -> Place {
        return try self.placesLock.withReadLock {
            guard index < displayedPlaces.endIndex,
                index >= displayedPlaces.startIndex else {
                    throw PlaceDataSourceError(message: "There is no place at index: \(index)")
            }

            return displayedPlaces[index]
        }
    }

    func index(forPlace place: Place) -> Int? {
        return self.placesLock.withReadLock {
            return placeKeyMap[place.id]
        }
    }

    func sortPlaces(byLocation location: CLLocation) {
        self.placesLock.withWriteLock {
            guard !topRatedOnly else { return }
            let sortedPlaces = PlaceUtilities.sort(places: displayedPlaces, byDistanceFromLocation: location)
            self.displayedPlaces = sortedPlaces
        }
    }

    func refresh(enabledFilters: Set<PlaceFilter>, topRatedOnly: Bool) {
        assert(Thread.isMainThread)

        var displayedPlaces: [Place]!
        placesLock.withWriteLock {
            self.enabledFilters = enabledFilters
            self.topRatedOnly = topRatedOnly
            updateDisplayedPlaces()
            displayedPlaces = self.displayedPlaces
        }

        delegate?.placesProvider(self, didUpdatePlaces: displayedPlaces)
    }

    func getDisplayedPlacesCopy() -> [Place] {
        var placesCopy: [Place] = []
        placesLock.withReadLock {
            placesCopy = Array(self.displayedPlaces)
        }
        return placesCopy
    }
}
