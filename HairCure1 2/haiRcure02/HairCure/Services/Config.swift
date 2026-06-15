import Foundation

enum Config {
    static var supabaseURL: URL {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        guard let urlString = rawValue, urlString != "$(SUPABASE_URL)", let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL is not correctly set. Did you forget to link Config.xcconfig in Xcode? Raw value found: '\(rawValue ?? "nil")'")
        }
        return url
    }
    
    static var supabaseAnonKey: String {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        guard let key = rawValue, key != "$(SUPABASE_ANON_KEY)" else {
            fatalError("SUPABASE_ANON_KEY is not correctly set. Did you forget to link Config.xcconfig in Xcode? Raw value found: '\(rawValue ?? "nil")'")
        }
        return key
    }
    
    static var openRouterAPIKey: String {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String
        guard let key = rawValue, key != "$(OPENROUTER_API_KEY)" else {
            fatalError("OPENROUTER_API_KEY is not correctly set. Did you forget to link Config.xcconfig in Xcode? Raw value found: '\(rawValue ?? "nil")'")
        }
        return key
    }
}
