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
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        captureSession = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
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
        videoPreviewLayer.connection?.videoOrientation = .portrait
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
        let image = UIImage(data: imageData)
        captureImageView.image = image
        guard let pixelBuffer = photo.pixelBuffer else { print("Failed to get pixel buffer"); return }
        let orientation = exifOrientationFromDeviceOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
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
            print("Got vision results")
            let objectObservations = results.compactMap { $0 as? VNRecognizedObjectObservation }
            print("Number of observations: \(objectObservations.count)")
            
            let cornerBBoxes = objectObservations.map {
                VNImageRectForNormalizedRect($0.boundingBox, Int(image.size.width), Int(image.size.height))
            }
            
            let filteredCornerBoxes = cornerBBoxes.enumerated()
                .filter { i, box1 in
                    // only take last intersecting bounding box
                    !cornerBBoxes[(i + 1)...].contains{ box2 in box1.intersects(box2)}
                        
                }.map { $1 }
            if filteredCornerBoxes.count != 4 {
                return
            }
            print("Got 4 corners!: \(filteredCornerBoxes)")
            
            let polygonPoints = filteredCornerBoxes.map { CGPoint(x: $0.midX, y: $0.midY) }
            let sortedPolygonPoints = polygonPoints.sorted { $0.x < $1.x }
            let firstIsTopLeft = sortedPolygonPoints[0].y < sortedPolygonPoints[1].y
            let rectangle: Rectangle = firstIsTopLeft
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
            
//            self.drawRectangleCorners(rect: rectangle)
            
                
//            let boardBBox: CGRect = detectedCornersToBBox(cornerBBoxes)
            
//            let perspectiveCorrectedImage = correctImagePerspective(pixelBuffer, )

        })
        
        return [objDetectionReq]
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
