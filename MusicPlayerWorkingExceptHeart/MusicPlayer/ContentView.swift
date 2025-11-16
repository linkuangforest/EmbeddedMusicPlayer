//
//  ContentView.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

// MARK: - Dark Theme Color Palette
extension Color {
    static let DarkBackground = Color(hex: "#131314") //Grey
    static let DarkBubbleUser = Color(hex: "#113252") // Blue
    static let DarkBubbleOther = Color(hex: "#303030") // Greyish
    static let DarkText = Color(hex: "#f8f8f2") //White
    static let DarkInputBackground = Color(hex: "#44475a") //Greyish
    static let DarkButton = Color(hex: "#1f2126")  //Greyish
    static let SendButtonText = Color(hex :"#92ccfb") //Light Blue
}
// MARK: - Chat Message Model
enum MessageContent {
    case text(String)
    case musicPlayer
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: MessageContent
    let isUser: Bool
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatBubble<Content: View>: View {
    let isUser: Bool
    @ViewBuilder let content: Content
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 20) }
            content
                .padding(10)
                .background(isUser ? Color.DarkBubbleUser : Color.DarkBubbleOther)
                .foregroundColor(Color.DarkText)
                .cornerRadius(15)
            if !isUser { Spacer(minLength: 20) }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var musicViewModel = MusicPlayerViewModel()
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: .text("Hi, How can I help?"), isUser: false)
    ]
    @State private var userChatInput = ""
    
    var body: some View {
        VStack(spacing: 5) {
            // Chat History
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(messages) { message in
                            switch message.content {
                            case .text(let text):
                                ChatBubble(isUser: message.isUser) {
                                    Text(text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal)
                                
                            case .musicPlayer:
                                MusicPlayerView(viewModel: musicViewModel)
                                    .accessibilityIdentifier("musicPlayerView")
                            }
                        }
                    }
                }
                .accessibilityIdentifier("chatScrollView")
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.DarkBackground)
            
            // Input Area
            HStack {
                TextField("Your message...", text: $userChatInput)
                    .padding(10)
                    .background(Color.DarkInputBackground)
                    .cornerRadius(10)
                    .foregroundColor(Color.DarkText)
                    .onSubmit {
                        sendMessage()
                    }
                    .colorScheme(.dark)
                    .accessibilityIdentifier("messageTextField")
                
                Button("Send") {
                    sendMessage()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.DarkButton)
                .foregroundColor(Color.SendButtonText)
                .cornerRadius(10)
                .disabled(userChatInput.isEmpty)
                .accessibilityIdentifier("sendButton")
            }
            .padding()
            .background(Color.DarkBackground)
        }
        .background(Color.DarkBackground.edgesIgnoringSafeArea(.all))
        .onAppear {
            ChatMusicController.shared.setup(viewModel: musicViewModel)
        }
    }
    
    func sendMessage() {
        guard !userChatInput.isEmpty else { return }
        
        let userMessage = ChatMessage(content: .text(userChatInput), isUser: true)
        messages.append(userMessage)
        let messageText = userChatInput
        userChatInput = ""
        
        // Simulate bot response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !messages.contains(where: { if case .musicPlayer = $0.content { return true } else { return false } }) {
                let tracks = self.loadBundleTracks()
                if !tracks.isEmpty {
                    self.musicViewModel.loadPlaylist(tracks)
                    let botMessage = ChatMessage(content: .musicPlayer, isUser: false)
                    self.messages.append(botMessage)
                } else {
                    let botMessage = ChatMessage(content: .text("Sorry, I couldn't load the music tracks."), isUser: false)
                    self.messages.append(botMessage)
                }
            } else {
                let botMessage = ChatMessage(content: .text("You said: \"\(messageText)\""), isUser: false)
                self.messages.append(botMessage)
            }
        }
    }
    
    // Function to load tracks from the bundle
    func loadBundleTracks() -> [MusicTrack] {
        var tracks: [MusicTrack] = []
        
        if let track1 = loadBundleTrack(title: "Black Friday (pretty like the sun)", artist: "Lost Frequencies, Tom Odell, Poppy Baskcomb", fileName: "Black Friday (pretty like the sun) - Lost Frequencies", albumArt: "Washed_Out_-_Purple_Noon") {
            tracks.append(track1)
        }
        if let track2 = loadBundleTrack(title: "Let It Be", artist: "The Beatles", fileName: "Let It Be") {
            tracks.append(track2)
        }
        if let track3 = loadBundleTrack(title: "To Get Better", artist: "Wasia Project", fileName: "To Get Better") {
            tracks.append(track3)
        }
        return tracks
    }
    
    func loadBundleTrack(title: String, artist: String, fileName: String, fileExtension: String = "mp3", albumArt: String? = nil) -> MusicTrack? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("ERROR: Local file \(fileName).\(fileExtension) not found in bundle.")
            return nil
        }
        return MusicTrack(title: title, artist: artist, albumArtAssetName: albumArt, audioURL: url, duration: 0)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
          // .environmentObject(AppState.shared) // If AppState is used via EnvironmentObject
    }
}
#endif
