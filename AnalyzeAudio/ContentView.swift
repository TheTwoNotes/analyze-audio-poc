//
//  ContentView.swift
//  AnalyzeAudio
//
//  Created by Gil Estes on 11/16/21.
//

import SwiftUI

struct ContentView: View {
	@State private var started: Bool = false
	@State private var currentDetectedSoundSource: String = "Ready to analyze!"
	
	var buttonText: String {
		if started {
			return "Stop"
		}
		return "Start"
	}
	
	var statusText: String {
		if started {
			return "Running"
		}
		return "Idle"
	}
	
	func updatedResult() {
		self.currentDetectedSoundSource = AnalyzeService.shared.currentItem
	}
	
	var body: some View {
		VStack {
			Text("Analyze Audio")
				.padding()
			
			Button(buttonText) {
				started.toggle()
				if started {
					AnalyzeService.shared.startAudioEngine()
				} else {
					AnalyzeService.shared.stopAudioEngine()
					currentDetectedSoundSource = "Ready to analyze!"
				}
			}
			.padding()
			.font(.body)
			
			Spacer()
			
			Text(self.currentDetectedSoundSource.capitalized.replacingOccurrences(of: "_", with: " ")).font(.title)
			
			Spacer()
		}
		.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResultUpdated")))
		{ obj in
			// Change key as per your "userInfo"
			self.currentDetectedSoundSource = AnalyzeService.shared.currentItem
			print("Update received in SwiftUI View")
		}
	}
}

extension NSNotification {
	static let ImageClick = Notification.Name.init("ImageClick")
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
