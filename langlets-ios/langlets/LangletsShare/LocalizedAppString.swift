import Foundation

// The account preference wins over the device language after signing in.
func localizedAppString(_ key: String, comment: String = "") -> String {
    let locale = UserDefaults(suiteName: "group.com.ynonp.langlets")?.string(forKey: "interfaceLocale")
    let bundle = locale.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
        .flatMap(Bundle.init(path:)) ?? Bundle.main
    return NSLocalizedString(key, bundle: bundle, comment: comment)
}
