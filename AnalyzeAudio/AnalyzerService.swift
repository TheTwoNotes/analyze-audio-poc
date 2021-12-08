//
//  AnalyzerService.swift
//  AnalyzeAudio
//
//  Created by Gil Estes on 11/16/21.
//

import Foundation
import AVFAudio
import SoundAnalysis
import SwiftUI
import CoreML

class AnalyzeService: NSObject, ObservableObject {

	@Published var currentItem: String = "None" {
		willSet {
			self.objectWillChange.send()
		}
	}

	static let shared = AnalyzeService()
	
	let analysisQueue = DispatchQueue(label: "com.bgesoftware.AnalysisQueue")

	var audioEngine: AVAudioEngine = AVAudioEngine()
	var inputBus: AVAudioNodeBus!
	var inputFormat: AVAudioFormat!
	
	var streamAnalyzer: SNAudioStreamAnalyzer!
	
	@ObservedObject var resultsObserver: ResultsObserver = ResultsObserver()
		
	func stopAudioEngine() {
		audioEngine.stop()
	}
	
	func startAudioEngine() {

		audioEngine = AVAudioEngine()
		inputBus = AVAudioNodeBus(0)
		inputFormat = audioEngine.inputNode.inputFormat(forBus: inputBus)
		
		do {
			try audioEngine.start()
			
			streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
						
			let classifySoundRequest = try makeRequest(GenderClassifierCoreMLModel(configuration: .init()).model)
			print(classifySoundRequest.knownClassifications)
			try streamAnalyzer.add(classifySoundRequest, withObserver: resultsObserver)

			installAudioTap()

			let nc = NotificationCenter.default
			nc.addObserver(self, selector: #selector(updatedResult), name: Notification.Name("ResultUpdated"), object: nil)

		} catch {
			print("Unable to start AVAudioEngine: \(error.localizedDescription)")
		}
	}
	
	func makeRequest(_ customModel: MLModel? = nil) throws -> SNClassifySoundRequest {

		if let model = customModel {
			let customRequest = try SNClassifySoundRequest(mlModel: model)
			return customRequest
		}
		
		let version1 = SNClassifierIdentifier.version1
		let request = try SNClassifySoundRequest(classifierIdentifier: version1)
		return request
	}
	
	@objc func updatedResult() {
		self.currentItem = resultsObserver.currentItem
	}
	
	func installAudioTap() {
		audioEngine.inputNode.installTap(onBus: inputBus,
										 bufferSize: 8192,
										 format: inputFormat,
										 block: analyzeAudio(buffer:at:))
	}
				
	func analyzeAudio(buffer: AVAudioBuffer, at time: AVAudioTime) {
		analysisQueue.async {
			self.streamAnalyzer.analyze(buffer,
										atAudioFramePosition: time.sampleTime)
		}
	}
}

class ResultsObserver: NSObject, SNResultsObserving, ObservableObject {
	
	var currentItem: String = "None"
	
	/// Notifies the observer when a request generates a prediction.
	func request(_ request: SNRequest, didProduce result: SNResult) {
		// Downcast the result to a classification result.
		guard let result = result as? SNClassificationResult else  { return }
		
		// Get the prediction with the highest confidence.
		guard let classification = result.classifications.first else { return }
		
		// Get the starting time.
		let timeInSeconds = result.timeRange.start.seconds
		
		// Convert the time to a human-readable string.
		let formattedTime = String(format: "%.2f", timeInSeconds)
		print("Analysis result for audio at time: \(formattedTime)")
		
		// Convert the confidence to a percentage string.
		let percent = classification.confidence * 100.0
		let percentString = String(format: "%.2f%%", percent)
		
		// Print the classification's name (label) with its confidence.
		print("\(classification.identifier): \(percentString) confidence.\n")
		
		//TODO: share this so UI can display it...
		self.currentItem = "\(classification.identifier): \(percentString)"
		
		let nc = NotificationCenter.default
		nc.post(name: Notification.Name("ResultUpdated"), object: nil)
	}
	
	/// Notifies the observer when a request generates an error.
	func request(_ request: SNRequest, didFailWithError error: Error) {
		print("The the analysis failed: \(error.localizedDescription)")
	}
	
	/// Notifies the observer when a request is complete.
	func requestDidComplete(_ request: SNRequest) {
		print("The request completed successfully!")
	}
}
