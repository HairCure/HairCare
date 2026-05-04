import Foundation
import Supabase

class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "")!,
            supabaseKey: ""
        )
    }
    
    var auth: AuthClient { client.auth }
}
