//
//  AnimatedGradientBackground.swift
//  documentAI
//
//  Animated mesh gradient background with rotation and movement
//

import SwiftUI

struct AnimatedGradientBackground: View {
    @State private var rotation: Double = -26
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var time: Double = 0
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            MeshGradientView()
                .blur(radius: 20)
                .opacity(0.8)
                .scaleEffect(2)
                .rotationEffect(.degrees(rotation))
                .offset(x: offsetX, y: offsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .onReceive(timer) { _ in
                    time += 0.0005
                    
                    // Smooth movement using sine/cosine
                    offsetX = sin(time * 0.8) * 50
                    offsetY = cos(time * 0.6) * 60 - 200
                    
                    // Swing rotation ±60 degrees from -26
                    rotation = sin(time * 0.5) * 60 - 26
                }
        }
    }
}

struct MeshGradientView: View {
    @State private var phase: Double = 0
    
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            // Create gradient with 4 colors
            let colors: [Color] = [
                Color(hex: "ef008f"), // Pink
                Color(hex: "6ec3f4"), // Blue
                Color(hex: "7038ff"), // Purple
                Color(hex: "ffba27")  // Yellow
            ]
            
            // Create animated mesh gradient effect
            let rect = CGRect(origin: .zero, size: size)
            
            // Draw multiple gradient layers for mesh effect
            for i in 0..<4 {
                let offset = Double(i) * 0.25
                let animatedPhase = phase + offset
                
                let startColor = colors[i % colors.count]
                let endColor = colors[(i + 1) % colors.count]
                
                let gradient = Gradient(colors: [
                    startColor.opacity(0.6),
                    endColor.opacity(0.6)
                ])
                
                let startPoint = CGPoint(
                    x: size.width * (0.5 + 0.3 * cos(animatedPhase)),
                    y: size.height * (0.5 + 0.3 * sin(animatedPhase))
                )
                
                let endPoint = CGPoint(
                    x: size.width * (0.5 + 0.3 * cos(animatedPhase + .pi)),
                    y: size.height * (0.5 + 0.3 * sin(animatedPhase + .pi))
                )
                
                context.fill(
                    Path(rect),
                    with: .linearGradient(
                        gradient,
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                )
            }
        }
        .onReceive(timer) { _ in
            phase += 0.000016 * 60 // Match gradient speed
        }
    }
}

#Preview {
    AnimatedGradientBackground()
}
