//
//  CameraPreviewView.swift
//  pinhole-cam
//
//  Created by Gilgamesh Craos on 4/14/26.
//

import SwiftUI
import AVFoundation

#if os(iOS)
struct CameraPreviewView: UIViewRepresentable {
	let session: AVCaptureSession
	
	// we create a UIView subclass that is backed by a video layer
	class VideoPreviewView: UIView {
		override class var layerClass: AnyClass {
			AVCaptureVideoPreviewLayer.self
		}
		
		var videoPreviewLayer: AVCaptureVideoPreviewLayer {
			return layer as! AVCaptureVideoPreviewLayer
		}
	}
	
	func makeUIView(context: Context) -> VideoPreviewView {
		let view = VideoPreviewView()
		view.videoPreviewLayer.session = session
		view.videoPreviewLayer.videoGravity = .resizeAspectFill
		return view
	}
	
	func updateUIView(_ uiView: VideoPreviewView, context: Context) {
		// here is where you'd handle screen rotations if needed
	}
	
}
#elseif os(macOS)
struct CameraPreviewView: NSViewRepresentable {
	let session: AVCaptureSession
	
	class VideoPreviewView: NSView {
		var videoPreviewLayer: AVCaptureVideoPreviewLayer!
		
		override init(frame frameRect: NSRect) {
			super.init(frame: frameRect)
			self.wantsLayer = true
		}
		
		required init?(coder: NSCoder){
			fatalError("init(coder:) has not been implemented")
		}
		
		// CALayer is an object used to manage image based content and perform animations on that content...might be useful for METAL or doing shader work...
		override func makeBackingLayer() -> CALayer {
			videoPreviewLayer = AVCaptureVideoPreviewLayer()
			videoPreviewLayer.videoGravity = .resizeAspectFill
			return videoPreviewLayer
		}
	}
	
	func makeNSView(contxet: Context) -> VideoPreviewView {
		let view = VideoPreviewView()
		view.videoPreviewLayer.session = session
		return view
	}
	
	func updateNSView(_ nsView: VideoPreviewView, context: Context) {
		
	}
}
#endif
