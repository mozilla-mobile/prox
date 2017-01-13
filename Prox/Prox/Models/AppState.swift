/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class AppState {
    enum State: String {
        case initial, loading, permissions, details, carousel, background, unknown
    }

    private static var cardVisits = Set<Int>()

    // Initial app state
    private static var state = State.initial
    private static var preBackgroundState: State?

    static func getState() -> State {
        return state
    }

    static func enterLoading() {
        updateSessionState(newState: State.loading)
    }

    static func requestPermissions() {
        if (state == State.loading) {
            // Stop loading session if handling permissions
            let params: [String: Any] = [AnalyticsEvent.PARAM_ACTION: AnalyticsEvent.PERMISSIONS]
            Analytics.endSession(sessionName: State.loading.rawValue + AnalyticsEvent.SESSION_SUFFIX, params: params)
            state = State.permissions
            print("[debug] endsession because permissions. New state: \(state)")
        } else {
            let params : [String: Any] = [AnalyticsEvent.SESSION_STATE: state.rawValue]
            Analytics.logEvent(event: AnalyticsEvent.PERMISSIONS, params: params)
            print("[debug] permissions event. Current state \(state)")
        }
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

    private static func updateSessionState(newState: State) {
        var params: [String: Any] = [:]
        if (cardVisits.count > 0) {
            params[AnalyticsEvent.NUM_CARDS] = cardVisits.count
            print("[debug] total cards seen: \(cardVisits.count)")
            cardVisits.removeAll()

            // Try to close a Detail card session, it's okay if it doesn't exist
            Analytics.endSession(sessionName: AnalyticsEvent.DETAILS_CARD_SESSION_DURATION, params: [:])
        }

        if (state != State.initial) {
            print("[debug] Previous state: " + state.rawValue)
            Analytics.endSession(sessionName: state.rawValue + AnalyticsEvent.SESSION_SUFFIX, params: params)
        }

        print("[debug] New state: " + newState.rawValue)
        state = newState

        Analytics.startSession(sessionName: state.rawValue + AnalyticsEvent.SESSION_SUFFIX, params: [:])
    }

    static func trackCardVisit(cardPos: Int) {
        // Try to close any Detail card sessions.
        Analytics.endSession(sessionName: AnalyticsEvent.DETAILS_CARD_SESSION_DURATION, params: [:])
        cardVisits.insert(cardPos)
        Analytics.startSession(sessionName: AnalyticsEvent.DETAILS_CARD_SESSION_DURATION, params: [AnalyticsEvent.CARD_INDEX: cardPos])
    }
}
