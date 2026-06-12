import Foundation
import Supabase

class SupabaseManager {
    
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://mkljovatslqpjtzvgnde.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rbGpvdmF0c2xxcGp0enZnbmRlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyOTc5MDYsImV4cCI6MjA5MTg3MzkwNn0.MRU-XWQvLSTNwUvmCvxEg4Ip-KnK2dyxCaeM9vFt9ME"
        )
    }
    
    var auth: AuthClient { client.auth }
}
