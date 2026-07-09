//
//  CameraManager.swift
//  pinhole-cam
//
//  Created by Gilgamesh Craos on 4/12/26.
//

import Foundation
import AVFoundation
import Combine

class CameraManager: NSObject, ObservableObject {
	let session = AVCaptureSession()
	
	private let photoOutput = AVCapturePhotoOutput()
	
	@Published var isCameraAuthorized = false
	@Published var capturedImage: Data?
	
	private let sessionQueue = DispatchQueue(label: "com.yourdomain.cameraQueue")
	
	override init() {
		super.init()
		checkPermissions()
	}
	
	// MARK: - permissions
	private func checkPermissions() {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
			case .authorized:
				self.isCameraAuthorized = true
				self.setupCamera()
			case .notDetermined:
				AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
					DispatchQueue.main.async {
						self?.isCameraAuthorized = granted
						if granted { self?.setupCamera() }
					}
				}
			default:
				self.isCameraAuthorized = false
		}
	}
		
	// MARK: - camera setup
	private func setupCamera() {
		sessionQueue.async{ [weak self] in
			guard let self = self else { return }
			
			self.session.beginConfiguration()
			
			// a. find the device (default rear camera)
			guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
				print("No camera was found")
				self.session.commitConfiguration()
				return
			}
			
			// b. create the input
			do {
				let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
				if self.session.canAddInput(videoDeviceInput) {
					self.session.addInput(videoDeviceInput)
				}
			} catch {
					print("Error creating input: \(error.localizedDescription)")
					self.session.commitConfiguration()
					return
			}
			
			// c. create the photo output
			if self.session.canAddOutput(self.photoOutput) {
				self.session.addOutput(self.photoOutput)
			}
			self.session.commitConfiguration()
		}
	}
		
	// MARK: - session control
	func startSession() {
		sessionQueue.async {
			if !self.session.isRunning {
				self.session.startRunning()
			}
		}
	}
	
	func stopSession() {
		sessionQueue.async {
			if self.session.isRunning {
				self.session.stopRunning()
			}
		}
	}
	
		// MARK: - photo capture
	func capturePhoto() {
		let settings = AVCapturePhotoSettings()
		//here you have the ability to config the flash, high res, etc.
		self.photoOutput.capturePhoto(with: settings, delegate: self)
	}
}

// Delegagte implementation to reviece the photo
extension CameraManager: AVCapturePhotoCaptureDelegate {
	func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard let data = photo.fileDataRepresentation() else { return }
	
		DispatchQueue.main.async {
			self.capturedImage = data
		}
	}
}
