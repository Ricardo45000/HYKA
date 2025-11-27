import SwiftUI

struct HykaLoaderView: View {
    @State private var animationState: AnimationState = .start
    @State private var hLeftLineProgress: CGFloat = 0
    @State private var hRightLineProgress: CGFloat = 0
    @State private var hBarRotation: CGFloat = 0
    @State private var kPosition: CGFloat = 0 // 0 = left, 0.5 = center, 1 = right
    @State private var kSpineProgress: CGFloat = 0
    @State private var kTopLegRotation: CGFloat = 0
    @State private var kBottomLegRotation: CGFloat = 0
    @State private var yPosition: CGFloat = -1 // -1 = above, 0 = center
    @State private var yRotation: CGFloat = 0
    @State private var dropletProgress: CGFloat = 0
    @State private var aLeftLegProgress: CGFloat = 0
    @State private var aRightLegProgress: CGFloat = 0
    @State private var finishLineProgress: CGFloat = 0
    @State private var hFinalOffset: CGFloat = 0
    @State private var yFinalOffset: CGFloat = 0
    @State private var kFinalOffset: CGFloat = 0
    @State private var aFinalOffset: CGFloat = 0
    @State private var letterHeightForKerning: CGFloat = 100 // Default, will be updated
    
    enum AnimationState {
        case start
        case hDrawn
        case kRunning
        case yDropping
        case aForming
        case final
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                let letterHeight: CGFloat = min(geometry.size.width, geometry.size.height) * 0.3
                let letterWidth: CGFloat = letterHeight * 0.6
                let strokeWidth: CGFloat = letterHeight * 0.08
                
                // Update letter height for kerning calculation
                let _ = updateLetterHeight(letterHeight)
                
                // Letter H
                if animationState != .start {
                    HLetter(
                        leftLineProgress: hLeftLineProgress,
                        rightLineProgress: hRightLineProgress,
                        barRotation: hBarRotation,
                        centerX: centerX,
                        centerY: centerY,
                        letterHeight: letterHeight,
                        letterWidth: letterWidth,
                        strokeWidth: strokeWidth,
                        offsetX: hFinalOffset
                    )
                }
                
                // Letter K
                if animationState != .start && animationState != .hDrawn {
                    KLetter(
                        spineProgress: kSpineProgress,
                        topLegRotation: kTopLegRotation,
                        bottomLegRotation: kBottomLegRotation,
                        centerX: centerX,
                        centerY: centerY,
                        letterHeight: letterHeight,
                        letterWidth: letterWidth,
                        strokeWidth: strokeWidth,
                        position: kPosition,
                        finalOffset: kFinalOffset
                    )
                }
                
                // Letter Y
                if animationState == .yDropping || animationState == .aForming || animationState == .final {
                    YLetter(
                        centerX: centerX,
                        centerY: centerY,
                        letterHeight: letterHeight,
                        letterWidth: letterWidth,
                        strokeWidth: strokeWidth,
                        position: yPosition,
                        rotation: yRotation,
                        finalOffset: yFinalOffset
                    )
                }
                
                // Droplet
                if animationState == .yDropping {
                    DropletView(
                        centerX: centerX,
                        centerY: centerY,
                        letterHeight: letterHeight,
                        progress: dropletProgress
                    )
                }
                
                // Letter A
                if animationState == .aForming || animationState == .final {
                    ALetter(
                        leftLegProgress: aLeftLegProgress,
                        rightLegProgress: aRightLegProgress,
                        finishLineProgress: finishLineProgress,
                        centerX: centerX,
                        centerY: centerY,
                        letterHeight: letterHeight,
                        letterWidth: letterWidth,
                        strokeWidth: strokeWidth,
                        finalOffset: aFinalOffset
                    )
                }
            }
            .onAppear {
                startAnimationSequence()
            }
        }
    }
    
    private func startAnimationSequence() {
        // State 1: Draw H (0.0s - 0.5s)
        withAnimation(.easeOut(duration: 0.3)) {
            hLeftLineProgress = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                hRightLineProgress = 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                hBarRotation = 1
            }
        }
        
        // State 2: K emerges and runs (0.5s - 1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animationState = .hDrawn
            withAnimation(.easeOut(duration: 0.2)) {
                kSpineProgress = 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animationState = .kRunning
            // K moves from left to center while legs animate
            withAnimation(.easeInOut(duration: 0.6)) {
                kPosition = 0.5
            }
            
            // Scissor run animation
            animateKLegs()
        }
        
        // State 3: Y drops (1.2s - 1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            animationState = .yDropping
            withAnimation(.easeIn(duration: 0.3)) {
                yPosition = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                yRotation = 45
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                dropletProgress = 1
            }
        }
        
        // State 4: A forms and K sprints (1.6s - 2.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            animationState = .aForming
            yPosition = -1
            yRotation = 0
            
            // A legs appear
            withAnimation(.easeOut(duration: 0.2)) {
                aLeftLegProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    aRightLegProgress = 1
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            // Finish line appears
            withAnimation(.easeOut(duration: 0.15)) {
                finishLineProgress = 0.8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            // K sprints to right
            withAnimation(.easeIn(duration: 0.3)) {
                kPosition = 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            // Finish line snaps into place
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                finishLineProgress = 1
            }
        }
        
        // State 5: Final kerning (2.2s - 2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            animationState = .final
            
            // Calculate final positions based on stored letter height
            let calculatedKerning = letterHeightForKerning * 0.15
            
            withAnimation(.easeOut(duration: 0.3)) {
                hFinalOffset = -calculatedKerning * 1.5 // H
                yFinalOffset = -calculatedKerning * 0.5  // Y
                kFinalOffset = calculatedKerning * 0.5   // K
                aFinalOffset = calculatedKerning * 1.5   // A
            }
        }
    }
    
    private func updateLetterHeight(_ height: CGFloat) {
        if letterHeightForKerning != height {
            DispatchQueue.main.async {
                letterHeightForKerning = height
            }
        }
    }
    
    private func animateKLegs() {
        // Scissor run: legs alternate back and forth
        func animate() {
            withAnimation(.easeInOut(duration: 0.15)) {
                kTopLegRotation = 25
                kBottomLegRotation = -25
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    kTopLegRotation = -25
                    kBottomLegRotation = 25
                }
                
                if animationState == .kRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        animate()
                    }
                }
            }
        }
        animate()
    }
}

// MARK: - Letter H
struct HLetter: View {
    let leftLineProgress: CGFloat
    let rightLineProgress: CGFloat
    let barRotation: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let letterHeight: CGFloat
    let letterWidth: CGFloat
    let strokeWidth: CGFloat
    let offsetX: CGFloat
    
    var body: some View {
        Path { path in
            let x = centerX + offsetX
            let leftX = x - letterWidth / 2
            let rightX = x + letterWidth / 2
            let topY = centerY - letterHeight / 2
            let bottomY = centerY + letterHeight / 2
            let barY = centerY
            
            // Left vertical line
            path.move(to: CGPoint(x: leftX, y: centerY))
            path.addLine(to: CGPoint(x: leftX, y: topY + (bottomY - topY) * (1 - leftLineProgress)))
            
            // Right vertical line
            path.move(to: CGPoint(x: rightX, y: centerY))
            path.addLine(to: CGPoint(x: rightX, y: topY + (bottomY - topY) * (1 - rightLineProgress)))
            
            // Horizontal bar (rotates out)
            let barLength = letterWidth * 0.6
            let rotationAngle = barRotation * .pi / 2
            let barStartX = leftX + (rightX - leftX) * 0.2
            let barEndX = rightX - (rightX - leftX) * 0.2
            
            let barCenterX = (barStartX + barEndX) / 2
            let rotatedStartX = barCenterX + (barStartX - barCenterX) * cos(rotationAngle) - (barY - barY) * sin(rotationAngle)
            let rotatedEndX = barCenterX + (barEndX - barCenterX) * cos(rotationAngle) - (barY - barY) * sin(rotationAngle)
            
            path.move(to: CGPoint(x: rotatedStartX, y: barY))
            path.addLine(to: CGPoint(x: rotatedEndX, y: barY))
        }
        .stroke(Color.white, lineWidth: strokeWidth)
    }
}

// MARK: - Letter K
struct KLetter: View {
    let spineProgress: CGFloat
    let topLegRotation: CGFloat
    let bottomLegRotation: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let letterHeight: CGFloat
    let letterWidth: CGFloat
    let strokeWidth: CGFloat
    let position: CGFloat // 0 = left, 0.5 = center, 1 = right
    let finalOffset: CGFloat
    
    private var calculatedX: CGFloat {
        // Calculate X position - break up complex expression
        let leftPosition = centerX - letterWidth * 2
        let centerPosition = centerX
        let rightPosition = centerX + letterWidth * 2
        
        if position <= 0.5 {
            // Moving from left to center
            let progress = position / 0.5
            let distance = centerPosition - leftPosition
            return leftPosition + distance * progress
        } else {
            // Moving from center to right
            let progress = (position - 0.5) / 0.5
            let distance = rightPosition - centerPosition
            return centerPosition + distance * progress
        }
    }
    
    private var currentX: CGFloat {
        let finalX = centerX + finalOffset
        return finalOffset != 0 ? finalX : calculatedX
    }
    
    var body: some View {
        Path { path in
            let topY = centerY - letterHeight / 2
            let bottomY = centerY + letterHeight / 2
            let midY = centerY
            let spineX = currentX - letterWidth / 2
            
            // Vertical spine
            let spineTop = topY + (bottomY - topY) * (1 - spineProgress)
            path.move(to: CGPoint(x: spineX, y: midY))
            path.addLine(to: CGPoint(x: spineX, y: spineTop))
            
            // Top leg
            let topLegLength = letterWidth * 0.7
            let topLegAngle = topLegRotation * .pi / 180
            let topLegEndX = spineX + topLegLength * cos(topLegAngle)
            let topLegEndY = midY - letterHeight * 0.2 + topLegLength * sin(topLegAngle)
            
            path.move(to: CGPoint(x: spineX, y: midY - letterHeight * 0.2))
            path.addLine(to: CGPoint(x: topLegEndX, y: topLegEndY))
            
            // Bottom leg
            let bottomLegLength = letterWidth * 0.7
            let bottomLegAngle = bottomLegRotation * .pi / 180
            let bottomLegEndX = spineX + bottomLegLength * cos(bottomLegAngle)
            let bottomLegEndY = midY + letterHeight * 0.2 + bottomLegLength * sin(bottomLegAngle)
            
            path.move(to: CGPoint(x: spineX, y: midY + letterHeight * 0.2))
            path.addLine(to: CGPoint(x: bottomLegEndX, y: bottomLegEndY))
        }
        .stroke(Color.white, lineWidth: strokeWidth)
    }
}

// MARK: - Letter Y
struct YLetter: View {
    let centerX: CGFloat
    let centerY: CGFloat
    let letterHeight: CGFloat
    let letterWidth: CGFloat
    let strokeWidth: CGFloat
    let position: CGFloat // -1 = above, 0 = center
    let rotation: CGFloat // degrees
    let finalOffset: CGFloat
    
    var body: some View {
        let y = centerY + (position == -1 ? -letterHeight * 1.5 : 0)
        let finalX = centerX + finalOffset
        let currentX = finalOffset != 0 ? finalX : centerX
        let rotAngle = rotation * .pi / 180
        
        Path { path in
            let topY = y - letterHeight / 2
            let midY = y
            let bottomY = y + letterHeight / 2
            let topX = currentX
            
            // Top V shape
            let leftTopX = topX - letterWidth * 0.3
            let rightTopX = topX + letterWidth * 0.3
            
            // Rotate points
            let centerPoint = CGPoint(x: currentX, y: midY)
            let leftTop = rotatePoint(
                point: CGPoint(x: leftTopX, y: topY),
                around: centerPoint,
                angle: rotAngle
            )
            let rightTop = rotatePoint(
                point: CGPoint(x: rightTopX, y: topY),
                around: centerPoint,
                angle: rotAngle
            )
            let bottom = rotatePoint(
                point: CGPoint(x: topX, y: bottomY),
                around: centerPoint,
                angle: rotAngle
            )
            
            path.move(to: leftTop)
            path.addLine(to: centerPoint)
            path.addLine(to: rightTop)
            path.move(to: centerPoint)
            path.addLine(to: bottom)
        }
        .stroke(Color.white, lineWidth: strokeWidth)
    }
    
    private func rotatePoint(point: CGPoint, around center: CGPoint, angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: center.x + dx * cosA - dy * sinA,
            y: center.y + dx * sinA + dy * cosA
        )
    }
}

// MARK: - Droplet
struct DropletView: View {
    let centerX: CGFloat
    let centerY: CGFloat
    let letterHeight: CGFloat
    let progress: CGFloat
    
    var body: some View {
        let startY = centerY - letterHeight * 0.3
        let endY = centerY + letterHeight * 0.3
        let currentY = startY + (endY - startY) * progress
        
        Circle()
            .fill(Color.white)
            .frame(width: letterHeight * 0.08, height: letterHeight * 0.08)
            .position(x: centerX, y: currentY)
            .opacity(progress > 0 && progress < 1 ? 1 : 0)
    }
}

// MARK: - Letter A
struct ALetter: View {
    let leftLegProgress: CGFloat
    let rightLegProgress: CGFloat
    let finishLineProgress: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    let letterHeight: CGFloat
    let letterWidth: CGFloat
    let strokeWidth: CGFloat
    let finalOffset: CGFloat
    
    var body: some View {
        let finalX = centerX + finalOffset
        
        Path { path in
            let topY = centerY - letterHeight / 2
            let midY = centerY
            let bottomY = centerY + letterHeight / 2
            let topX = finalX
            
            // Left leg
            let leftTop = CGPoint(x: topX - letterWidth * 0.4, y: topY)
            let leftBottom = CGPoint(x: topX - letterWidth * 0.5, y: bottomY)
            let leftCurrentTop = CGPoint(
                x: leftTop.x,
                y: leftTop.y + (leftBottom.y - leftTop.y) * (1 - leftLegProgress)
            )
            
            path.move(to: leftTop)
            path.addLine(to: leftCurrentTop)
            
            // Right leg
            let rightTop = CGPoint(x: topX + letterWidth * 0.4, y: topY)
            let rightBottom = CGPoint(x: topX + letterWidth * 0.5, y: bottomY)
            let rightCurrentTop = CGPoint(
                x: rightTop.x,
                y: rightTop.y + (rightBottom.y - rightTop.y) * (1 - rightLegProgress)
            )
            
            path.move(to: rightTop)
            path.addLine(to: rightCurrentTop)
            
            // Finish line / Crossbar
            let barY = midY
            let barStartX = leftTop.x + (leftBottom.x - leftTop.x) * 0.3
            let barEndX = rightTop.x + (rightBottom.x - rightTop.x) * 0.3
            let barCurrentEndX = barStartX + (barEndX - barStartX) * finishLineProgress
            
            path.move(to: CGPoint(x: barStartX, y: barY))
            path.addLine(to: CGPoint(x: barCurrentEndX, y: barY))
        }
        .stroke(Color.white, lineWidth: strokeWidth)
    }
}

#Preview {
    HykaLoaderView()
}

