import SwiftUI
import Combine

// Define enums for the dropdowns
enum QuestionType: String, CaseIterable {
    case any = "Any Type"
    case multiple = "Multiple Choice"
    case boolean = "True or False"
}

enum TimerDuration: String, CaseIterable {
    case thirtySeconds = "30 seconds"
    case sixtySeconds = "60 seconds"
    case onetwentySeconds = "120 seconds"
    case threeHundredSeconds = "300 seconds"
    case oneHour = "1 hour"
}

// Add these structures for the API response
struct TriviaCategory: Codable, Identifiable {
    let id: Int
    let name: String
}

struct TriviaCategoryResponse: Codable {
    let triviaCategories: [TriviaCategory]
    
    enum CodingKeys: String, CodingKey {
        case triviaCategories = "trivia_categories"
    }
}

// Add this structure for the trivia questions
struct TriviaQuestion: Codable, Identifiable {
    let id = UUID()
    let category: String
    let type: String
    let difficulty: String
    let question: String
    let correct_answer: String
    let incorrect_answers: [String]
}

struct TriviaResponse: Codable {
    let response_code: Int
    let results: [TriviaQuestion]
}

struct ContentView: View {
    @State private var numberOfQuestions = 5
    @State private var selectedCategory: TriviaCategory?
    @State private var categories: [TriviaCategory] = []
    @State private var difficulty = 1.0
    @State private var selectedType: QuestionType = .any
    @State private var selectedDuration: TimerDuration = .thirtySeconds
    @State private var isTimerDropdownShown = false
    @State private var questions: [TriviaQuestion] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isGameStarted = false
    
    private var difficultyText: String {
        switch difficulty {
        case 0..<0.67: return "Easy"
        case 0.67..<1.33: return "Medium"
        default: return "Hard"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Blue header with title
                    ZStack {
                        Color.blue
                        Text("Trivia Game")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 40)
                    }
                    .frame(height: 120)
                    
                    // Main content
                    VStack(alignment: .leading, spacing: 25) {
                        // Number of Questions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of Questions")
                                .foregroundColor(.black)
                            TextField("Number of Questions", value: $numberOfQuestions, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Category Selection - Updated to use Menu
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Category")
                                .foregroundColor(.black)
                            Menu {
                                Button("Any Category") {
                                    selectedCategory = nil
                                }
                                ForEach(categories) { category in
                                    Button(category.name) {
                                        selectedCategory = category
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory?.name ?? "Any Category")
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        // Difficulty
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty: \(difficultyText)")
                                .foregroundColor(.black)
                            Slider(value: $difficulty, in: 0...2, step: 0.1)
                                .tint(.blue)
                        }
                        
                        // Type Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Type")
                                .foregroundColor(.black)
                            Menu {
                                ForEach(QuestionType.allCases, id: \.self) { type in
                                    Button(type.rawValue) {
                                        selectedType = type
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedType.rawValue)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        // Timer Duration - Modified Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timer Duration")
                                .foregroundColor(.black)
                            Button(action: {
                                withAnimation {
                                    isTimerDropdownShown.toggle()
                                }
                            }) {
                                HStack {
                                    Text(selectedDuration.rawValue)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            if isTimerDropdownShown {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(TimerDuration.allCases, id: \.self) { duration in
                                        Button(action: {
                                            selectedDuration = duration
                                            isTimerDropdownShown = false
                                        }) {
                                            HStack {
                                                if duration == selectedDuration {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                }
                                                Text(duration.rawValue)
                                                    .foregroundColor(.black)
                                                Spacer()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal)
                                        }
                                        .background(Color.white)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .zIndex(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .background(Color.white)
                    
                    // Blue footer with button
                    ZStack {
                        Color.blue
                        Button(action: {
                            Task {
                                await startGame()
                            }
                        }) {
                            Text("Start Trivia")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(25)
                                .padding(.horizontal)
                        }
                    }
                    .frame(height: 100)
                }
                .task {
                    await loadCategories()
                }
                .ignoresSafeArea()
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
            }
            .navigationDestination(isPresented: $isGameStarted) {
                GameView(questions: questions, selectedDuration: selectedDuration)
            }
        }
    }
    
    // Add function to load categories
    private func loadCategories() async {
        guard let url = URL(string: "https://opentdb.com/api_category.php") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TriviaCategoryResponse.self, from: data)
            categories = response.triviaCategories
        } catch {
            print("Error loading categories: \(error)")
        }
    }
}

// Move the extension outside of ContentView struct
extension ContentView {
    private func startGame() async {
        var urlComponents = URLComponents(string: "https://opentdb.com/api.php")
        var queryItems = [
            URLQueryItem(name: "amount", value: "\(numberOfQuestions)")
        ]
        
        // Add category if selected
        if let category = selectedCategory {
            queryItems.append(URLQueryItem(name: "category", value: "\(category.id)"))
        }
        
        // Add difficulty
        let apiDifficulty: String
        switch difficultyText.lowercased() {
        case "easy": apiDifficulty = "easy"
        case "medium": apiDifficulty = "medium"
        case "hard": apiDifficulty = "hard"
        default: apiDifficulty = "medium"
        }
        queryItems.append(URLQueryItem(name: "difficulty", value: apiDifficulty))
        
        // Add type if not "any"
        if selectedType != .any {
            let apiType = selectedType == .multiple ? "multiple" : "boolean"
            queryItems.append(URLQueryItem(name: "type", value: apiType))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            errorMessage = "Invalid URL"
            showError = true
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Debug print
            print("URL being called:", url.absoluteString)
            print("Raw response:", String(data: data, encoding: .utf8) ?? "No data")
            
            let response = try JSONDecoder().decode(TriviaResponse.self, from: data)
            
            if response.response_code == 0 && !response.results.isEmpty {
                questions = response.results
                isGameStarted = true
            } else {
                errorMessage = getErrorMessage(for: response.response_code)
                if response.results.isEmpty {
                    errorMessage += "\nTry reducing the number of questions or changing the category/difficulty."
                }
                showError = true
            }
        } catch {
            print("Decoding error:", error)
            errorMessage = "Error loading questions: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func getErrorMessage(for code: Int) -> String {
        switch code {
        case 1: return "Not enough questions available for your criteria. Try reducing the number of questions or changing the category/difficulty."
        case 2: return "Invalid parameter in request. Please check your selections."
        case 3: return "Session token not found"
        case 4: return "Session token has returned all questions"
        case 5: return "Too many requests. Please wait a few seconds and try again."
        default: return "Unknown error occurred. Please try different settings."
        }
    }
}

// Add this new view for displaying questions
struct GameView: View {
    let questions: [TriviaQuestion]
    let selectedDuration: TimerDuration
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var selectedAnswer: String?
    @State private var isGameComplete = false
    @State private var timeRemaining: Int
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var timerConnector: Cancellable?
    @Environment(\.dismiss) private var dismiss
    @State private var shuffledAnswers: [String] = []
    
    init(questions: [TriviaQuestion], selectedDuration: TimerDuration) {
        self.questions = questions
        self.selectedDuration = selectedDuration
        let seconds: Int
        switch selectedDuration {
        case .thirtySeconds: seconds = 30
        case .sixtySeconds: seconds = 60
        case .onetwentySeconds: seconds = 120
        case .threeHundredSeconds: seconds = 300
        case .oneHour: seconds = 3600
        }
        _timeRemaining = State(initialValue: seconds)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !isGameComplete {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(timeRemaining < 10 ? .red : .blue)
                    Text(timeString(from: timeRemaining))
                        .font(.title2)
                        .foregroundColor(timeRemaining < 10 ? .red : .blue)
                        .bold()
                }
                .padding()
                
                // Question counter
                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(.headline)
                
                // Question
                Text(questions[currentQuestionIndex].question
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#039;", with: "'"))
                    .font(.title2)
                    .padding()
                    .multilineTextAlignment(.center)
                
                // Answers
                VStack(spacing: 12) {
                    ForEach(shuffledAnswers, id: \.self) { answer in
                        Button(action: {
                            selectAnswer(answer)
                        }) {
                            Text(answer
                                .replacingOccurrences(of: "&quot;", with: "\"")
                                .replacingOccurrences(of: "&#039;", with: "'"))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedAnswer == answer ? Color.blue : Color.gray)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Next button
                if selectedAnswer != nil {
                    Button(currentQuestionIndex == questions.count - 1 ? "Finish Game" : "Next Question") {
                        nextQuestion()
                    }
                    .font(.title3)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                // Updated Game complete view
                VStack(spacing: 20) {
                    Text("Game Complete! 🎉")
                        .font(.title)
                        .bold()
                    
                    Text("Your Final Score:")
                        .font(.title2)
                    
                    Text("\(score) out of \(questions.count)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue)
                    
                    Text("Percentage: \(Int((Double(score) / Double(questions.count)) * 100))%")
                        .font(.title3)
                        .padding(.bottom)
                    
                    Button("Play Again") {
                        dismiss()
                    }
                    .font(.title3)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .padding()
        .navigationTitle("Trivia Game")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: currentQuestionIndex) { _ in
            shuffleAnswers()
        }
        .onAppear {
            shuffleAnswers()
            startTimer()
        }
        .onDisappear {
            timerConnector?.cancel()
        }
    }
    
    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
    }
    
    private func nextQuestion() {
        if let selected = selectedAnswer {
            if selected == questions[currentQuestionIndex].correct_answer {
                score += 1
            }
        }
        if currentQuestionIndex == questions.count - 1 {
            isGameComplete = true
            timerConnector?.cancel()
        } else {
            currentQuestionIndex += 1
            selectedAnswer = nil
        }
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
        timerConnector = timer.connect()
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isGameComplete = true
                timerConnector?.cancel()
            }
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func shuffleAnswers() {
        let currentQuestion = questions[currentQuestionIndex]
        shuffledAnswers = (currentQuestion.incorrect_answers + [currentQuestion.correct_answer]).shuffled()
    }
}

// Add this at the bottom of your file, after the ContentView struct
#Preview {
    ContentView()
}

// Or if you're using an older version of Xcode, use this syntax:
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
