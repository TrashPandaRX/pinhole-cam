//
//  ContentView.swift
//  pinhole-cam
//
//  Created by Gilgamesh Craos on 3/11/26.
//

import SwiftUI

struct CameraMainView: View {
	@StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
			// darker background for the camera
			Color.black.ignoresSafeArea()

			if cameraManager.isCameraAuthorized {
				// 1. the preview layer in the background
				CameraPreviewView(session: cameraManager.session)
					.ignoresSafeArea()
					.onAppear() {
						cameraManager.startSession()
					}
					.onDisappear() {
						cameraManager.stopSession()
					}
				// 2. overlaid ui elements
				VStack {
					Spacer()
					
					// camera controls
					HStack{
						Spacer()
						
						Button(action: {
							cameraManager.capturePhoto()
						}) {
							Circle()
								.stroke(Color.white, lineWidth: 3)
								.frame(width: 70, height: 70)
						}
					}
				}
			}
		}
    }
}

#Preview {
    CameraMainView()
}
