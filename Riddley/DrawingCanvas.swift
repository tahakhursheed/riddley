import SwiftUI
import PencilKit
import Vision

#if os(iOS)
struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let onSave: (String) -> Void
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        var toolPicker: PKToolPicker?
        var lastRecognitionTask: DispatchWorkItem?
        var isInitialized = false
        var lastStrokeTime: Date?
        private let writingPauseThreshold: TimeInterval = 0.5 // Time to wait after last stroke
        
        init(_ parent: DrawingCanvas) {
            self.parent = parent
            super.init()
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            lastStrokeTime = Date()
            scheduleTextRecognition(for: canvasView)
        }
        
        func scheduleTextRecognition(for canvasView: PKCanvasView) {
            // Cancel any previous recognition task
            lastRecognitionTask?.cancel()
            
            // Create a new recognition task
            let task = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Check if enough time has passed since the last stroke
                if let lastStroke = self.lastStrokeTime {
                    let timeSinceLastStroke = Date().timeIntervalSince(lastStroke)
                    if timeSinceLastStroke < self.writingPauseThreshold {
                        // If we're still writing, don't process yet
                        return
                    }
                }
                
                // Convert drawing to image
                let drawing = canvasView.drawing
                let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
                
                // Perform text recognition
                self.recognizeText(from: image) { [weak self] recognizedText in
                    guard let recognizedText = recognizedText, !recognizedText.isEmpty else {
                        return
                    }
                    
                    // Call the onSave closure on the main thread
                    DispatchQueue.main.async {
                        self?.parent.onSave(recognizedText)
                    }
                }
            }
            
            // Schedule the task with a delay to allow for continuous writing
            lastRecognitionTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + writingPauseThreshold, execute: task)
        }
        
        private func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
            guard let cgImage = image.cgImage else {
                print("Failed to get CGImage")
                completion(nil)
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Text recognition error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(nil)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(10).first?.string
                }.joined(separator: " ")
                
                completion(recognizedText.isEmpty ? nil : recognizedText)
            }
            
            // Adjust recognition parameters for better handwriting recognition
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.1
            request.customWords = ["hello", "world"]
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("Text recognition error: \(error.localizedDescription)")
                completion(nil)
            }
        }
        
        func setupCanvas(_ canvasView: PKCanvasView) {
            guard !isInitialized else { return }
            
            canvasView.delegate = self
            // Set drawing policy to allow both finger and pencil input
            canvasView.drawingPolicy = .anyInput
            canvasView.backgroundColor = .clear
            
            // Use a thicker pen for better recognition
            let inkingTool = PKInkingTool(.pen, color: .black, width: 8)
            canvasView.tool = inkingTool
            
            isInitialized = true
        }
        
        func setupToolPicker(for canvasView: PKCanvasView) {
            guard toolPicker == nil else { return }
            
            toolPicker = PKToolPicker()
            toolPicker?.setVisible(true, forFirstResponder: canvasView)
            toolPicker?.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        // Set drawing policy to allow both finger and pencil input
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        
        // Configure tool picker
        context.coordinator.setupToolPicker(for: canvasView)
        
        // Set default tool
        let inkingTool = PKInkingTool(.pen, color: .black, width: 2)
        canvasView.tool = inkingTool
        
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Minimal updates if needed
        context.coordinator.setupToolPicker(for: canvasView)
    }
}

#else
struct DrawingCanvas: View {
    @Binding var canvasView: Any
    let onSave: (String) -> Void
    
    var body: some View {
        Text("Drawing canvas is only available on iOS")
            .foregroundColor(.red)
    }
}
#endif