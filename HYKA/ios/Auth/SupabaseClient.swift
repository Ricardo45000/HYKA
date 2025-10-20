import Foundation
import Supabase
import Auth

enum Supa {
    static let client: SupabaseClient = {
        let url = URL(string: Config.supabaseURL)!
        let key = Config.supabaseAnonKey
        
        // Configure with redirect URL for OAuth
        let redirectURL = URL(string: Config.garminRedirectURI)!
        
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(
                auth: .init(
                    redirectToURL: redirectURL
                )
            )
        )
    }()
}
