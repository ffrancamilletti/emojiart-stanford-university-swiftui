//
//  ContentView.swift
//  Shared
//
//  Created by Franco Camilletti on 17/03/2022.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                )
                .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: oneTapOnBackgroundToDeselect()))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .border(selectedEmojis.contains(emoji) ? Color.blue : Color.clear)
                            .scaleEffect(selectedEmojis.contains(emoji) ? emojiZoomScale : emojiSteadyStateZoomScale)
                            .scaleEffect(zoomScale)
                            .font(.system(size: fontSize(for: emoji)))
                            .position(position(for: emoji, in: geometry))
                            .gesture(oneTapToSelect(emoji: emoji))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: pinchToZoom()))
        }
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(EmojiArtModel.Background.url(url.imageURL))
        }
        if !found {
            found =  providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    @State private var draggedEmojiPosition: CGSize = CGSize.zero
    @GestureState private var emojiDragGestureValue: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private var emojiPanOffset: CGSize {
        (draggedEmojiPosition + emojiDragGestureValue) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func emojiDragGesture(emoji: EmojiArtModel.Emoji ) -> some Gesture {
        DragGesture()
            .updating($emojiDragGestureValue) { latestDragGestureValue, emojiGesturePanOffset, transaction in
                emojiGesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                draggedEmojiPosition = draggedEmojiPosition + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    @State var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    private func oneTapToSelect(emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                selectedEmojis.toggleMembership(of: emoji)
            }
    }
    
    private func oneTapOnBackgroundToDeselect() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                selectedEmojis.removeAll()
            }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    var defaultEmojiFontSize: CGFloat = 50
    @State private var emojiSteadyStateZoomScale: CGFloat = 1
    @GestureState private var emojiZoomGestureScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private var emojiZoomScale: CGFloat {
        emojiSteadyStateZoomScale * emojiZoomGestureScale
    }
    
    private func pinchToZoom() -> some Gesture {
        if selectedEmojis.isEmpty {
            return MagnificationGesture()
                .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                    gestureZoomScale = latestGestureScale
                }
                .onEnded { gestureScaleAtEnd in
                    steadyStateZoomScale *= gestureScaleAtEnd
                }
        } else {
            return MagnificationGesture()
                .updating($emojiZoomGestureScale) { latestGestureScale, emojiZoomGestureScale, transaction in
                    emojiZoomGestureScale = latestGestureScale
                }
                .onEnded { gestureScaleAtEnd in
                    emojiSteadyStateZoomScale *= gestureScaleAtEnd
                }
        }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis: String = "⛱🗻🗿🚢🚁🏯🏩🎠🚀🏛"
}

struct ScrollingEmojisView: View {
    let emojis: String
    var body: some View {
        
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
