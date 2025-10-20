import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                Text("Privacy Policy")
                    .font(HYKATheme.h2)
                    .foregroundColor(HYKATheme.Light.foreground)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                
                Text("Last Updated: November 2024")
                    .font(HYKATheme.caption)
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    SectionView(
                        title: "1. Introduction",
                        content: """
                        HYKA ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.
                        """
                    )
                    
                    SectionView(
                        title: "2. Information We Collect",
                        content: """
                        We collect information that you provide directly to us, including:
                        • Personal information (name, email address, birth date, gender)
                        • Running profile data (distances, experience level)
                        • Race planning data (GPX files, race details, preferences)
                        • Device connection data (when you connect wearable devices)
                        • Health and fitness data from connected devices
                        """
                    )
                    
                    SectionView(
                        title: "3. How We Use Your Information",
                        content: """
                        We use the information we collect to:
                        • Provide, maintain, and improve our services
                        • Personalize your race planning and strategy recommendations
                        • Process transactions and send related information
                        • Send technical notices, updates, and support messages
                        • Respond to your comments and questions
                        • Monitor and analyze trends and usage
                        """
                    )
                    
                    SectionView(
                        title: "4. Data Storage and Security",
                        content: """
                        Your data is stored securely using Supabase, a cloud database service. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet or electronic storage is 100% secure.
                        """
                    )
                    
                    SectionView(
                        title: "5. Third-Party Services",
                        content: """
                        We may use third-party services that collect information used to identify you, including:
                        • Supabase (database and authentication)
                        • Garmin, Polar, Coros, Suunto (wearable device data)
                        • Tomorrow.io (weather data)
                        
                        These third parties have their own privacy policies addressing how they use such information.
                        """
                    )
                    
                    SectionView(
                        title: "6. Data Sharing",
                        content: """
                        We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:
                        • With your consent
                        • To comply with legal obligations
                        • To protect our rights and safety
                        • In connection with a business transfer
                        """
                    )
                    
                    SectionView(
                        title: "7. Your Rights",
                        content: """
                        You have the right to:
                        • Access your personal data
                        • Correct inaccurate data
                        • Request deletion of your data
                        • Object to processing of your data
                        • Data portability
                        • Withdraw consent at any time
                        
                        To exercise these rights, please contact us at privacy@hyka.app
                        """
                    )
                    
                    SectionView(
                        title: "8. Children's Privacy",
                        content: """
                        Our App is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.
                        """
                    )
                    
                    SectionView(
                        title: "9. Changes to This Privacy Policy",
                        content: """
                        We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.
                        """
                    )
                    
                    SectionView(
                        title: "10. Contact Us",
                        content: """
                        If you have any questions about this Privacy Policy, please contact us at:
                        Email: privacy@hyka.app
                        Website: https://hyka.app/privacy
                        """
                    )
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.bottom, HYKATheme.spacingXXL)
            }
        }
        .background(HYKATheme.backgroundColor)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}

