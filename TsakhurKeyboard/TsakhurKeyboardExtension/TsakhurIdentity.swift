//
//  TsakhurIdentity.swift
//  TsakhurKeyboardExtension
//
//  Product identifiers that the keyboard AND the container app both need.
//  Compiled into both targets (a target-membership exception), so the App
//  Group is spelled once in code. It must match the TSAKHUR_APP_GROUP_ID
//  build setting, which both .entitlements files expand.
//
//  Debug and Release use different App Groups on purpose. Debug builds are
//  signed by the developer's own team (automatic signing); App Group and
//  bundle identifiers are unique across all Apple developer teams, so if a
//  Debug build registered the production identifiers, the distribution team
//  could no longer register them. Debug therefore uses `.dev` identifiers
//  and leaves the production ones untouched. The keyboard keeps its learned
//  words and settings in its own container either way (General Keyboard
//  never stores them in the App Group); the group only carries the inert
//  contribution bridge.
//

enum TsakhurIdentity {
    /// App Store identity. Never changes once released.
    static let releaseAppGroupID = "group.org.lekitech.tsakhurkeyboard"
    /// Development identity, registered under the developer's own team.
    static let debugAppGroupID = "group.org.lekitech.tsakhurkeyboard.dev"

    #if DEBUG
    static let appGroupID = debugAppGroupID
    #else
    static let appGroupID = releaseAppGroupID
    #endif
}
