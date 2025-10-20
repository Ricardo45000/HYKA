import SwiftUI

// MARK: - Google Logo

struct GoogleLogo: View {
    var size: CGFloat = 24
    
    var body: some View {
        Image("GoogleIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Facebook Logo

struct FacebookLogo: View {
    var size: CGFloat = 24
    
    var body: some View {
        Image("FacebookIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

struct SocialLoginIcons_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            HStack(spacing: 32) {
                GoogleLogo(size: 24)
                GoogleLogo(size: 32)
                GoogleLogo(size: 48)
            }
            
            HStack(spacing: 32) {
                FacebookLogo(size: 24)
                FacebookLogo(size: 32)
                FacebookLogo(size: 48)
            }
        }
        .padding()
        .background(Color.white)
        .previewLayout(.sizeThatFits)
    }
}


