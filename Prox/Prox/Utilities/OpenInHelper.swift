/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


import Foundation
import MapKit

struct OpenInHelper {

    static let gmapsAppSchemeString: String = "comgooglemaps://"
    static let gmapsWebSchemeString: String = "https://www.google.com/maps"
    static let appleMapsSchemeString: String = "http://maps.apple.com/"

    //MARK: Open URL in Browser
    static func openURLInBrowser(url: URL) -> Bool {
        // check to see if Firefox is available
        // Open in Firefox or Safari
        let controller = OpenInFirefoxControllerSwift()
        if !(controller.isFirefoxInstalled() && controller.openInFirefox(url)) {
            return UIApplication.shared.openURL(url)
        }

        return true
    }

    //MARK: Open URL general
    fileprivate static func openURL(url: URL) -> Bool {
        // check to see if we can open in Google Maps
        if UIApplication.shared.canOpenURL(url) {
            return UIApplication.shared.openURL(url)
        }

        return false
    }

    //MARK: Open route in maps

    static func openRoute(fromLocation: CLLocationCoordinate2D, toPlace place: Place, by transportType: MKDirectionsTransportType) -> Bool {
        // try and open in Google Maps app
        if let gmapsRoutingRequestURL = gmapsAppURLForRoute(fromLocation: fromLocation, toLocation: place.latLong, by: transportType),
            openURL(url: gmapsRoutingRequestURL) {
            return true
        // open in Apple maps app
        } else if let address = place.address,
            let appleMapsRoutingRequest = appleMapsURLForRoute(fromLocation: fromLocation, toAddress: address, by: transportType),
            openURL(url: appleMapsRoutingRequest)
        {
            return true
        // open google maps in a browser
        } else if let gmapsRoutingRequestURL = gmapsWebURLForRoute(fromLocation: fromLocation, toLocation: place.latLong, by: transportType),
            openURLInBrowser(url: gmapsRoutingRequestURL) {
            return true
        }
        print("Unable to open directions")
        return false
    }

    fileprivate static func gmapsAppURLForRoute(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, by transportType: MKDirectionsTransportType) -> URL? {
        let directionsMode: String
        switch transportType {
        case MKDirectionsTransportType.automobile:
            directionsMode = "driving"
        case MKDirectionsTransportType.transit:
            directionsMode = "transit"
        case MKDirectionsTransportType.walking:
            directionsMode = "walking"
        default:
            directionsMode = ""
            return nil
        }
        let queryParams = ["saddr=\(fromLocation.latitude),\(fromLocation.longitude)", "daddr=\(toLocation.latitude),\(toLocation.longitude)", "directionsMode=\(directionsMode)"]

        let gmapsRoutingRequestURLString = gmapsAppSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: gmapsRoutingRequestURLString)
    }


    fileprivate static func gmapsWebURLForRoute(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, by transportType: MKDirectionsTransportType) -> URL? {
        guard let dirFlg = dirFlgForTransportType(transportType: transportType) else {
            return nil
        }
        let queryParams = ["saddr=\(fromLocation.latitude),\(fromLocation.longitude)", "daddr=\(toLocation.latitude),\(toLocation.longitude)", "dirflg=\(dirFlg)"]

        let gmapsRoutingRequestURLString = gmapsWebSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: gmapsRoutingRequestURLString)
    }


    fileprivate static func appleMapsURLForRoute(fromLocation: CLLocationCoordinate2D, toAddress: String, by transportType: MKDirectionsTransportType) -> URL? {
        guard let dirFlg = dirFlgForTransportType(transportType: transportType) else {
            return nil
        }

        let queryParams = ["daddr=\(encodeByAddingPercentEscapes(toAddress))", "dirflg=\(dirFlg)"]

        let appleMapsRoutingRequestURLString = appleMapsSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: appleMapsRoutingRequestURLString)
    }

    fileprivate static func dirFlgForTransportType(transportType: MKDirectionsTransportType) -> String? {
        switch transportType {
        case MKDirectionsTransportType.automobile:
            return "d"
        case MKDirectionsTransportType.transit:
            return "r"
        case MKDirectionsTransportType.walking:
            return "w"
        default:
            return nil
        }
    }

    //MARK: Helper functions
    fileprivate static func encodeByAddingPercentEscapes(_ input: String) -> String {
        return NSString(string: input).addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]"))!
    }
}
