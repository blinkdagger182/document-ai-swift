//
//  AnimatedGradientBackground.swift
//  documentAI
//
//  Animated gradient background using WebView with minigl.js
//

import SwiftUI
import WebKit

struct AnimatedGradientBackground: View {
    var body: some View {
        GradientWebView()
            .ignoresSafeArea()
    }
}

struct GradientWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        let htmlString = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body, html {
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                }
                
                .background--custom {
                    background-color: #FFFFFF;
                    width: 100vw;
                    height: 100vh;
                    position: absolute;
                    overflow: hidden;
                    z-index: -2;
                    top: 0;
                    left: 0;
                }
                
                canvas#canvas {
                    z-index: -1;
                    position: absolute;
                    width: 100%;
                    height: 35%;
                    transform-origin: 50% 0%;
                    transform: rotate(-26deg) scale(2) translateY(-30%);
                    --gradient-color-1: #ef008f; 
                    --gradient-color-2: #6ec3f4; 
                    --gradient-color-3: #7038ff;  
                    --gradient-color-4: #ffba27;
                    --gradient-speed: 0.000016;
                    filter: blur(20px);
                    opacity: 0.8;
                }
            </style>
        </head>
        <body>
            <div class="background--custom">
                <canvas id="canvas"></canvas>
            </div>
            
            <script src="https://cdn.jsdelivr.net/gh/greentfrapp/pocoloco@minigl/minigl.js"></script>
            <script>
                var gradient = new Gradient();
                gradient.initGradient("#canvas");
                
                // Animate the canvas position and rotation around top
                const canvas = document.getElementById('canvas');
                let time = 0;
                
                function animatePosition() {
                    time += 0.0005;
                    
                    // Calculate smooth movement using sine/cosine
                    const moveX = Math.sin(time * 0.8) * 15;
                    const moveY = Math.cos(time * 0.6) * 20;
                    
                    // Rotate around the top of the screen (swinging motion)
                    const rotation = Math.sin(time * 0.5) * 60 - 26; // Swing ±60 degrees from -26
                    
                    canvas.style.transform = `rotate(${rotation}deg) scale(2) translateY(-30%) translateX(${moveX}%) translateY(${moveY}%)`;
                    
                    requestAnimationFrame(animatePosition);
                }
                
                animatePosition();
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}

#Preview {
    AnimatedGradientBackground()
}
