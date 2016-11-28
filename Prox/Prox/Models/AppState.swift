/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class AppState {
    enum State: String {
        case loading, details, carousel, background, exiting, unknown
    }

    private static var cardVisits = Set<Int>()

    // Initial app state
    private static var state = State.loading
    private static var preBackgroundState: State?

    static func getState() -> State {
        return state
    }

    static func enterBackground() {
        print("[debug] entering background from: " + state.rawValue)
        preBackgroundState = state
        updateSessionState(newState: State.background)
    }

    static func enterForeground() {
        let safeState = preBackgroundState != nil ? preBackgroundState! : State.unknown
        print("[debug] resuming to preBackground state: " + safeState.rawValue)
        updateSessionState(newState: safeState)
        preBackgroundState = nil
    }

    static func enterCarousel() {
        updateSessionState(newState: State.carousel)
    }

    static func enterDetails() {
        updateSessionState(newState: State.details)
    }

    static func exiting() {
        updateSessionState(newState: State.exiting)
    }

    private static func updateSessionState(newState: State) {
        print("[debug] Previous state: " + state.rawValue)
        var params: [String: Any] = [:]
        if (cardVisits.count > 0) {
            params[AnalyticsEvent.NUM_CARDS] = cardVisits.count
            print(cardVisits.count)
            cardVisits.removeAll()
        }
        Analytics.endSession(sessionName: state.rawValue + AnalyticsEvent.SESSION_SUFFIX, params: params)

        print("[debug] New state: " + newState.rawValue)
        state = newState

        if (state != State.exiting) {
            Analytics.startSession(sessionName: state.rawValue + AnalyticsEvent.SESSION_SUFFIX, params: [:])
        }
    }

    static func trackCardVisit(cardPos: Int) {
        cardVisits.insert(cardPos)
    }
}
