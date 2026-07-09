//
//  ContentView.swift
//  pinhole-cam
//
//  Created by Gilgamesh Craos on 3/11/26.
// based on the guide by Ramiro Rafart https://swiftprogramming.com/camera-swiftui/

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
								.overlay( Circle()
									.fill(Color.white)
									.frame(width: 60, height: 60)
								)
						}
						.padding( .bottom, 30)
						
						Spacer()
					}
				}
				
				// show the captured photo if it exists
				if let capturedImage = cameraManager.capturedImage,
				   #available(iOS 16.0, macOS 13.0, *),
				   let image = platformImage(from: capturedImage) {
					
					VStack {
						HStack {
							Spacer()
							Image(nsImageOrUIImage: image)
								.resizable()
								.scaledToFit()
								.frame(width: 100, height: 150)
								.cornerRadius(10)
								.shadow(radius: 5)
								.padding()
								.onTapGesture {
									// discard the photo
									withAnimation{
										cameraManager.capturedImage = nil
									}
								}
						}
						Spacer()

					}
				}
			} else {
					// denied permissions screen
			  VStack(spacing: 20) {
				  Image(systemName: "camera.slash")
					  .font( .system( size:50 ) )
					  .foregroundColor(.gray)
				  Text("No camera access")
					  .font( .title3 )
					  .foregroundColor(.white)
				  Text("Please enable access in Settings")
					  .foregroundColor(.gray)
			  }
		  }
		}
    }
	//crossplatform helper function to process data to image
	#if os(iOS)
	func platformImage(from data: Data) -> UIImage? {
		UIImage(data: data)
	}
	#elseif os(macOS)
	func platformImage(from data: Data) -> NSImage? {
		NSImage(data: data)
	}
	#endif
}

// extension to facilitate cross-platform initialization in SwiftUI
extension Image {
	#if os(iOS)
	init(nsImageOrUIImage image: UIImage) {
		self.init(uiImage: image)
	}
	#elseif os(macOS)
	init(nsImageOrUIImage image: NSImage) {
		self.init(nsImage: image)
	}
	#endif
}

#Preview {
    CameraMainView()
}
