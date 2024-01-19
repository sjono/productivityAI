import SwiftUI
import OpenAI // Import the MacPaw/OpenAI package

struct ContentView: View {
    @State private var task: String = ""
    @State private var conversationHistory: [Message] = [Message(role: .ai, sender: "ProductivityAI Bot", content: "What is your TOP task for today?")]
    @State private var awaitingUserResponse: Bool = false

    var body: some View {
        ScrollViewReader { scrollView in
            VStack {
                ScrollView {
                    LazyVStack {
                        ForEach(conversationHistory, id: \.id) { message in
                            MessageView(message: message)
                        }
                    }
                    .padding(.horizontal)
                }
                
                ZStack(alignment: .topLeading) {
                    if task.isEmpty {
                        Text("Input here")
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $task)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 80)
                        .lineLimit(3)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
                        .onTapGesture {
                            // Do something if needed
                        }
                        .onSubmit {
                            appendResponseToHistory(Message(role: .user, sender: "You", content: task))
                            let submittedTask = task
                            task = ""
                            initiateChat(submittedTask)
                        }
                }

                Button("Submit") {
                    appendResponseToHistory(Message(role: .user, sender: "You", content: task))
                    let submittedTask = task
                    task = ""
                    initiateChat(submittedTask)
                }
                .padding()
            }
            .padding()
            .onAppear {
                // Scroll to the bottom of the chat history when the view appears
                scrollView.scrollTo(conversationHistory.last?.id, anchor: .bottom)
            }
            .onChange(of: conversationHistory) { _ in
                // Scroll to the bottom of the chat history when new messages are added
                scrollView.scrollTo(conversationHistory.last?.id, anchor: .bottom)
            }
        }
    }

    
    
    func initiateChat(_ submittedTask: String) {
        let initialMessage = "My task for the day is \(submittedTask). Please ask one insightful question to help me change the task description to be more helpful or productive"

        // Initialize a ChatQuery object with the modified initial message
        let initialChatQuery = ChatQuery(
            model: .gpt3_5Turbo,
            messages: [
                Chat(role: .user, content: initialMessage)
            ]
        )

        // Load OpenAI key and create configuration
        if let openAIKey = loadOpenAIKey() {
            let configuration = OpenAI.Configuration(token: openAIKey, timeoutInterval: 60.0)
            let openAI = OpenAI(configuration: configuration)
            
            // Send the initial chat request to the OpenAI API using chats method
            Task {
                do {
                    // Send the initial chat request to the OpenAI API using chats method
                    let initialChatResult = try await openAI.chats(query: initialChatQuery)
                    if let initialResponse = initialChatResult.choices.first?.message.content {
                        appendResponseToHistory(Message(role: .ai, sender: "ProductivityAI Bot", content: initialResponse))
                        
                        // Ask for a clarifying question
                        let clarifyingQuestionQuery = ChatQuery(
                            model: .gpt3_5Turbo,
                            messages: [
                                Chat(role: .user, content: "Could you provide more details about your task?")
                            ]
                        )
                        let clarifyingQuestionResult = try await openAI.chats(query: clarifyingQuestionQuery)
                        if let clarifyingQuestionResponse = clarifyingQuestionResult.choices.first?.message.content {
                            appendResponseToHistory(Message(role: .ai, sender: "ProductivityAI Bot", content: clarifyingQuestionResponse))
                            awaitingUserResponse = true // Set awaitingUserResponse to true after asking the clarifying question
                        } else {
                            appendResponseToHistory(Message(role: .ai, sender: "ProductivityAI Bot", content: "Error: Empty response for clarifying question"))
                        }
                    } else {
                        appendResponseToHistory(Message(role: .ai, sender: "ProductivityAI Bot", content: "Error: Empty response from OpenAI"))
                    }
                } catch {
                    // Handle the error
                    appendResponseToHistory(Message(role: .ai, sender: "ProductivityAI Bot", content: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    
    func loadOpenAIKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Dictionary", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path),
              let secrets = try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainers, format: nil) as? [String: String],
              let openAIKey = secrets["OpenAIKey"] else {
            fatalError("Secrets.plist is missing OpenAIKey or the file is corrupted.")
        }
        return openAIKey
    }
    
    func appendResponseToHistory(_ message: Message) {
            conversationHistory.append(message)
            awaitingUserResponse = message.role == .ai // Set awaitingUserResponse based on the role of the received message
        }
}



struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let sender: String // Add sender property
    let content: String
}

enum Role {
    case user
    case ai
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                Text(message.content)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.blue)
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text(message.sender) // Show sender's name in smaller text
                        .font(.caption) // Set font size to caption
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
    }
}
