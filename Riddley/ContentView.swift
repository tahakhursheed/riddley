//
//  ContentView.swift
//  Riddley
//
//  Created by Taha Khursheed on 11/11/24.
//

import SwiftUI
import PencilKit
import Vision

struct ContentView: View {
    @StateObject private var viewModel = ConversationViewModel()
    @State private var canvasView = PKCanvasView()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingExport = false
    @State private var exportText = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                HStack {
                    Picker("Mode", selection: $viewModel.mode) {
                        Text("Magical").tag(DiaryMode.magical)
                        Text("Memory").tag(DiaryMode.memory)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if viewModel.mode == .memory {
                        Button(action: {
                            exportText = viewModel.exportConversation()
                            showingExport = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                        .padding(.trailing)
                    }
                }
                
                ZStack {
                    // Drawing canvas (input)
                    DrawingCanvasContainer(canvasView: canvasView) { recognizedText in
                        Task {
                            await viewModel.processNewEntry(
                                drawing: canvasView.drawing,
                                text: recognizedText,
                                position: .zero
                            )
                            // Clear the canvas after processing in magical mode
                            if viewModel.mode == .magical {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        canvasView.drawing = PKDrawing()
                                    }
                                }
                            }
                        }
                    }
                    .background(Color.clear)
                    
                    // Responses
                    if viewModel.mode == .memory {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.entries) { entry in
                                    VStack(alignment: .leading, spacing: 10) {
                                        if let response = entry.aiResponse {
                                            MagicalResponseView(text: response)
                                                .padding(.leading, 20)
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                    } else {
                        // Magical mode - show only latest response
                        if let lastEntry = viewModel.entries.last,
                           let response = lastEntry.aiResponse {
                            MagicalResponseView(text: response)
                                .padding(.leading, 20)
                        }
                    }
                }
                
                HStack {
                    Button(action: {
                        canvasView.drawing = PKDrawing()
                    }) {
                        Image(systemName: "trash")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.clearAll()
                        canvasView.drawing = PKDrawing()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingExport) {
            NavigationView {
                ScrollView {
                    Text(exportText)
                        .padding()
                }
                .navigationTitle("Export Conversation")
                .navigationBarItems(
                    trailing: Button("Done") { showingExport = false }
                )
            }
        }
    }
}

struct DrawingView: View {
    let drawing: PKDrawing
    
    var body: some View {
        DrawingCanvas(canvasView: .constant(PKCanvasView()), onSave: { _ in })
            .onAppear {
                let canvas = PKCanvasView()
                canvas.drawing = drawing
                canvas.isUserInteractionEnabled = false
            }
    }
}

struct DrawingCanvasContainer: UIViewRepresentable {
    let canvasView: PKCanvasView
    let onSave: (String) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: DrawingCanvasContainer
        var lastRecognitionTask: DispatchWorkItem?
        private let debounceInterval: TimeInterval = 0.5
        
        init(_ parent: DrawingCanvasContainer) {
            self.parent = parent
            super.init()
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Cancel any pending recognition task
            lastRecognitionTask?.cancel()
            
            // Create a new recognition task
            let task = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Ensure there's actually something drawn
                guard !canvasView.drawing.bounds.isEmpty && canvasView.drawing.strokes.count > 0 else {
                    print("🖌️ No drawing detected")
                    return
                }
                
                // Create a snapshot of the drawing
                let renderer = UIGraphicsImageRenderer(bounds: canvasView.drawing.bounds)
                let drawnImage = renderer.image { context in
                    canvasView.drawing.image(from: canvasView.drawing.bounds, scale: 1.0).draw(in: canvasView.drawing.bounds)
                }
                
                // Perform text recognition
                let requestHandler = VNImageRequestHandler(cgImage: drawnImage.cgImage!, options: [:])
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        print("❌ Text recognition error: \(error)")
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        print("❌ No text observations found")
                        return
                    }
                    
                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    let recognizedText = recognizedStrings.joined(separator: " ")
                    if !recognizedText.isEmpty {
                        DispatchQueue.main.async {
                            self.parent.onSave(recognizedText)
                        }
                    }
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                do {
                    try requestHandler.perform([request])
                } catch {
                    print("❌ Failed to perform recognition: \(error)")
                }
            }
            
            // Schedule the recognition task with debounce
            lastRecognitionTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: task)
        }
    }
}

#Preview {
    ContentView()
}
