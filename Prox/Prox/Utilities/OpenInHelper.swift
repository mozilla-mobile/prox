/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


import Foundation
import MapKit

private enum Scheme: String {
    case yelp = "yelp"
    case tripAdvisor = "tripadvisor"
    case wikipedia = "wikipedia"
}

struct OpenInHelper {

    static let gmapsAppSchemeString: String = "comgooglemaps://"
    static let gmapsWebSchemeString: String = "https://www.google.com/maps"
    static let appleMapsSchemeString: String = "http://maps.apple.com/"
    static let yelpAppURLSchemeString: String = "yelp://"
    static let tripAdvisorAppURLSchemeString: String = "tripadvisor://"
    static let wikipediaAppURLSchemeString: String = "wikipedia://"

    @discardableResult static func open(url: URL, analyticsStr: String, errStr: String) -> Bool {
        let didOpen = openInner(url: url)
        if didOpen {
            Analytics.logEvent(event: analyticsStr, params: [:])
        } else {
            log.error(errStr)
        }

        return didOpen
    }

    private static func openInner(url: URL) -> Bool {
        guard let host = url.host,
            let hostname = extractHostname(fromHost: host),
            let scheme = Scheme(rawValue: hostname),
            let schemeURL = schemeURL(forScheme: scheme),
            UIApplication.shared.canOpenURL(schemeURL),
            UIApplication.shared.openURL(url) else {
            return openURLInBrowser(url: url)
        }

        return true
    }

    private static func extractHostname(fromHost host: String) -> String? {
        // We assume hosts have a *.*.* url format  (which is true for our currently supported hosts)
        let components = host.components(separatedBy: ".")
        if components.count > 0 {
            return components[1]
        } else {
            return nil
        }
    }

    fileprivate static func schemeURL(forScheme scheme: Scheme) -> URL? {
        switch scheme {
        case .yelp:
            return URL(string: yelpAppURLSchemeString)
        case .tripAdvisor:
            return URL(string: tripAdvisorAppURLSchemeString)
        case .wikipedia:
            return URL(string: wikipediaAppURLSchemeString)
        }
    }

    //MARK: Open URL in Browser
    fileprivate static func openURLInBrowser(url: URL) -> Bool {
        // check to see if Firefox is available
        // Open in Firefox or Safari
        let controller = OpenInFirefoxControllerSwift()
        if !controller.openInFirefox(url) {
            return UIApplication.shared.openURL(url)
        }

        return true
    }

    //MARK: Open route in maps

    static func openRoute(fromLocation: CLLocationCoordinate2D, toPlace place: Place, by transportType: MKDirectionsTransportType, analyticsStr: String, errStr: String) {
        let didOpen = openRouteInner(fromLocation: fromLocation, toPlace: place, by: transportType)
        if didOpen {
            Analytics.logEvent(event: analyticsStr, params: [AnalyticsEvent.PARAM_ACTION: transportType.name])
        } else {
            log.error(errStr)
        }
    }

    private static func openRouteInner(fromLocation: CLLocationCoordinate2D, toPlace place: Place, by transportType: MKDirectionsTransportType) -> Bool {
        // try and open in Google Maps app
        if let schemeURL = URL(string: gmapsAppSchemeString),
            UIApplication.shared.canOpenURL(schemeURL),
            let gmapsRoutingRequestURL = gmapsAppURLForRoute(fromLocation: fromLocation, toLocation: place.latLong, by: transportType),
            UIApplication.shared.openURL(gmapsRoutingRequestURL) {
            return true
        // open in Apple maps app
        } else if  let schemeURL = URL(string: appleMapsSchemeString),
            UIApplication.shared.canOpenURL(schemeURL),
            let appleMapsRoutingRequest = appleMapsURLForRoute(fromLocation: fromLocation, toLocation: place.latLong, by: transportType),
            UIApplication.shared.openURL(appleMapsRoutingRequest) {
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

        guard let directionsMode = transportType.directionsMode() else { return nil }

        let queryParams = ["saddr=\(fromLocation.latitude),\(fromLocation.longitude)", "daddr=\(toLocation.latitude),\(toLocation.longitude)", "directionsMode=\(directionsMode)"]

        let gmapsRoutingRequestURLString = gmapsAppSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: gmapsRoutingRequestURLString)
    }


    fileprivate static func gmapsWebURLForRoute(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, by transportType: MKDirectionsTransportType) -> URL? {
        guard let dirFlg = transportType.dirFlg() else {
            return nil
        }
        let queryParams = ["saddr=\(fromLocation.latitude),\(fromLocation.longitude)", "daddr=\(toLocation.latitude),\(toLocation.longitude)", "dirflg=\(dirFlg)"]

        let gmapsRoutingRequestURLString = gmapsWebSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: gmapsRoutingRequestURLString)
    }


    fileprivate static func appleMapsURLForRoute(fromLocation: CLLocationCoordinate2D, toLocation: CLLocationCoordinate2D, by transportType: MKDirectionsTransportType) -> URL? {
        guard let dirFlg = transportType.dirFlg() else {
            return nil
        }

        let queryParams = ["daddr=\(toLocation.latitude),\(toLocation.longitude)", "dirflg=\(dirFlg)"]

        let appleMapsRoutingRequestURLString = appleMapsSchemeString + "?" + queryParams.joined(separator: "&")
        return URL(string: appleMapsRoutingRequestURLString)
    }

    //MARK: Helper functions
    fileprivate static func encodeByAddingPercentEscapes(_ input: String) -> String {
        return NSString(string: input).addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]"))!
    }
}

fileprivate extension MKDirectionsTransportType {
    func dirFlg() -> String? {
        switch self {
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

    func directionsMode() -> String? {
        switch self {
        case MKDirectionsTransportType.automobile:
            return "driving"
        case MKDirectionsTransportType.transit:
            return "transit"
        case MKDirectionsTransportType.walking:
            return "walking"
        default:
            return nil
        }
    }
}
