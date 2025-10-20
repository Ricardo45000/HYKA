import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                Text("Terms of Service")
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
                        title: "1. Acceptance of Terms",
                        content: """
                        By accessing and using HYKA ("the App"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.
                        """
                    )
                    
                    SectionView(
                        title: "2. Description of Service",
                        content: """
                        HYKA is a mobile application designed to help ultra runners plan and execute their race strategies. The App provides personalized pacing, nutrition, and race planning features based on user-provided data and preferences.
                        """
                    )
                    
                    SectionView(
                        title: "3. User Accounts",
                        content: """
                        You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.
                        """
                    )
                    
                    SectionView(
                        title: "4. User Conduct",
                        content: """
                        You agree to use the App only for lawful purposes and in a way that does not infringe the rights of, restrict or inhibit anyone else's use and enjoyment of the App. Prohibited behavior includes harassing or causing distress or inconvenience to any person, transmitting obscene or offensive content, or disrupting the normal flow of dialogue within the App.
                        """
                    )
                    
                    SectionView(
                        title: "5. Health and Safety Disclaimer",
                        content: """
                        The App provides information and recommendations for race planning purposes only. The information provided is not intended to replace professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay in seeking it because of something you have read in the App.
                        """
                    )
                    
                    SectionView(
                        title: "6. Data and Privacy",
                        content: """
                        Your use of the App is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices regarding the collection and use of your personal information.
                        """
                    )
                    
                    SectionView(
                        title: "7. Intellectual Property",
                        content: """
                        The App and its original content, features, and functionality are owned by HYKA and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.
                        """
                    )
                    
                    SectionView(
                        title: "8. Limitation of Liability",
                        content: """
                        In no event shall HYKA, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your use of the App.
                        """
                    )
                    
                    SectionView(
                        title: "9. Changes to Terms",
                        content: """
                        We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect.
                        """
                    )
                    
                    SectionView(
                        title: "10. Contact Information",
                        content: """
                        If you have any questions about these Terms of Service, please contact us at support@hyka.app
                        """
                    )
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.bottom, HYKATheme.spacingXXL)
            }
        }
        .background(HYKATheme.backgroundColor)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            Text(title)
                .font(HYKATheme.h4)
                .foregroundColor(HYKATheme.Light.foreground)
            
            Text(content)
                .font(HYKATheme.body)
                .foregroundColor(HYKATheme.Light.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
}

