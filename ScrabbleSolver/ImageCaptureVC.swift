//
//  ImageCaptureVC.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/21/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import AVFoundation
import Vision

class ImageCaptureVC : UIViewController {
    

    // MARK: IBOutlet
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureImageView: UIImageView!
    
    @IBAction func buttonTapped(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: Class Variables
    
    var camera: AVCaptureDevice?
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var timer: Timer?
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        captureSession = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10, repeats: true) { timer in
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                self.stillImageOutput.capturePhoto(with: settings, delegate: self)
            }
        }
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main, using: didRotate)
    }
   
    func didRotate(_ notification: Notification) {
        videoPreviewLayer.connection?.videoOrientation = exifOrientationFromDeviceOrientation()
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            print("landscape")
        case .portrait, .portraitUpsideDown:
            print("Portrait")
        default:
            print("other")
        }

    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup your camera here...
        
        captureSession.sessionPreset = .medium
        guard let camera = AVCaptureDevice.default(for: .video) else { print("Failed to get capture device"); return }
        self.camera = camera
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch let error {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
            return
        }
        if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
            captureSession.addInput(input)
            captureSession.addOutput(stillImageOutput)
            setupLivePreview()
        }
    }
    
    func setupLivePreview() {
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = exifOrientationFromDeviceOrientation()
//        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
    }
}

extension ImageCaptureVC : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
//        let imageRequestHandler = VNImageRequestHandler(data: imageData, orientation: exifOrientationFromDeviceOrientation(), options: [:])
        let imageRequestHandler = VNImageRequestHandler(data: imageData, options: [:])

        do {
            let image = UIImage(data: imageData)
            DispatchQueue.main.async { self.captureImageView.image = image }
            let requests = try generateRequests(image: image!)
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }

    }

}

extension ImageCaptureVC {
    func generateRequests(image: UIImage) throws -> [VNRequest] {
        // Setup Vision parts
        guard let modelURL = Bundle.main.url(forResource: "IndoorOutdoor", withExtension: "mlmodelc") else {
            throw NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        
        let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
        let objDetectionReq = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
            // perform all the UI updates on the main queue
            guard let results = request.results else {
                print("Failed to get vision results")
                return
            }
            let objectObservations = results.compactMap { $0 as? VNRecognizedObjectObservation }
            
            let cornerBBoxes = objectObservations.map { VNImageRectForNormalizedRect($0.boundingBox, Int(image.size.width), Int(image.size.height)) }
            
            let filteredCornerBoxes = cornerBBoxes.enumerated()
                .filter { i, box1 in
                    // only take last intersecting bounding box
                    !cornerBBoxes[(i + 1)...].contains{ box2 in box1.intersects(box2)}
                        
                }.map { $1 }
            if filteredCornerBoxes.count != 4 {
                return
            }
            
            let polygonPoints = filteredCornerBoxes.map { CGPoint(x: $0.midX, y: $0.midY) }
            let sortedPolygonPoints = polygonPoints.sorted { $0.x < $1.x }
            let firstIsTopLeft = sortedPolygonPoints[0].y < sortedPolygonPoints[1].y
            let quad: Quadrilateral = firstIsTopLeft
                ? (
                    topLeft: sortedPolygonPoints[0],
                    topRight: sortedPolygonPoints[1],
                    bottomRight: sortedPolygonPoints[3],
                    bottomLeft: sortedPolygonPoints[2]
                )
                : (
                    topLeft: sortedPolygonPoints[1],
                    topRight: sortedPolygonPoints[0],
                    bottomRight: sortedPolygonPoints[2],
                    bottomLeft: sortedPolygonPoints[3]
                )
            
            let size = 24
            let y = Int(image.size.height - (quad.topLeft.y - CGFloat(size / 2)))
            let tlRect = CGRect(
                x: Int(quad.topLeft.x) - size / 2,
                y: Int(image.size.height - (quad.topLeft.y - CGFloat(size / 2))),
                width: size,
                height: size)
            let trRect = CGRect(
                x: Int(quad.topRight.x) - size / 2,
                y: Int(image.size.height - (quad.topRight.y - CGFloat(size / 2))),
                width: size,
                height: size)
            let brRect = CGRect(
                x: Int(quad.bottomRight.x) - size / 2,
                y: Int(image.size.height - (quad.bottomRight.y - CGFloat(size / 2))),
                width: size,
                height: size)
            let blRect = CGRect(
                x: Int(quad.bottomLeft.x) - size / 2,
                y: Int(image.size.height - (quad.bottomLeft.y - CGFloat(size / 2))),
                width: size,
                height: size)

            if let cgImageCopy = image.cgImage?.copy() {
//                var drawnImage = UIImage(cgImage: cgImageCopy)
                var drawnImage = UIImage(cgImage: cgImageCopy, scale: 1.0, orientation: .right)
                
                drawnImage = self.drawRectangleOnImage(image: drawnImage, rectangle: tlRect) ?? drawnImage
                drawnImage = self.drawRectangleOnImage(image: drawnImage, rectangle: trRect) ?? drawnImage
                drawnImage = self.drawRectangleOnImage(image: drawnImage, rectangle: brRect) ?? drawnImage
                drawnImage = self.drawRectangleOnImage(image: drawnImage, rectangle: blRect) ?? drawnImage
                DispatchQueue.main.async {
                    self.captureImageView.image = drawnImage
                }
            }
            
//            self.drawRectangleCorners(rect: rectangle)
            
                
//            let boardBBox: CGRect = detectedCornersToBBox(cornerBBoxes)
            
//            let perspectiveCorrectedImage = correctImagePerspective(pixelBuffer, )

        })
        
        return [objDetectionReq]
    }
    
    func drawRectangleOnImage(image: UIImage, rectangle: CGRect) -> UIImage? {
        let imageSize = image.size
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        image.draw(at: CGPoint.zero)
        context.setFillColor(UIColor.yellow.cgColor)
        context.addRect(rectangle)
        context.drawPath(using: .fill)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

}

func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
    let curDeviceOrientation = UIDevice.current.orientation
    let exifOrientation: CGImagePropertyOrientation
    
    switch curDeviceOrientation {
    case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
        exifOrientation = .left
    case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
        exifOrientation = .upMirrored
    case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
        exifOrientation = .down
    case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
        exifOrientation = .up
    default:
        exifOrientation = .up
    }
    return exifOrientation
}

func exifOrientationFromDeviceOrientation() -> AVCaptureVideoOrientation {
    let curDeviceOrientation = UIDevice.current.orientation
    let exifOrientation: AVCaptureVideoOrientation
    
    switch curDeviceOrientation {
    case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
        exifOrientation = .portraitUpsideDown
    case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
        exifOrientation = .landscapeRight
    case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
        exifOrientation = .landscapeLeft
    case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
        exifOrientation = .portrait
    default:
        exifOrientation = .portrait
    }
    print(exifOrientation)
    return exifOrientation
}


extension UIImage {
    func toPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
          return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}

