//
//  ObjectRecognitionViewController.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/20/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import AVFoundation
import Vision

typealias Rectangle = (
    topLeft: CGPoint,
    topRight: CGPoint,
    bottomRight: CGPoint,
    bottomLeft: CGPoint
)

class ObjectRecognitionViewController : AVCaptureViewController {

    private var requests = [VNRequest]()
    private var detectionOverlay: CALayer! = nil

    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        
        // start the capture
        startCaptureSession()
    }

    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            let requests = try generateRequests(pixelBuffer: pixelBuffer)
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }

    
    func generateRequests(pixelBuffer: CVPixelBuffer) throws -> [VNRequest] {
        // Setup Vision parts
//        let error: NSError! = nil
        
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
    //                for observation in results where observation is VNRecognizedObjectObservation {
            let objectObservations = results.compactMap { $0 as? VNRecognizedObjectObservation }
            print("Number of observations: \(objectObservations.count)")

            let cornerBBoxes = objectObservations.map {
                VNImageRectForNormalizedRect($0.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
            }
            
            let filteredCornerBoxes = cornerBBoxes.enumerated()
                .filter { i, box1 in
                    // only take last intersecting bounding box
                    !cornerBBoxes[(i + 1)...].contains{ box2 in box1.intersects(box2)}
                        
                }.map { $1 }
            if filteredCornerBoxes.count != 4 {
                self.clearDetectionOverlay()
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
          
            self.drawRectangleCorners(rect: rectangle)
            
                
//            let boardBBox: CGRect = detectedCornersToBBox(cornerBBoxes)
            
//            let perspectiveCorrectedImage = correctImagePerspective(pixelBuffer, )

        })
        
        return [objDetectionReq]
    }

    func clearDetectionOverlay() {
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            self.detectionOverlay.sublayers = nil // remove all the old recognized objects
            CATransaction.commit()
        }
    }
    
    func drawRectangleCorners(rect: Rectangle) {
        let size = 24
        
        let tl = CGRect(
            x: Int(rect.topLeft.x) - size / 2,
            y: Int(rect.topLeft.y) - size / 2,
            width: size,
            height: size)
        let tr = CGRect(
            x: Int(rect.topRight.x) - size / 2,
            y: Int(rect.topRight.y) - size / 2,
            width: size,
            height: size)
        let br = CGRect(
            x: Int(rect.bottomRight.x) - size / 2,
            y: Int(rect.bottomRight.y) - size / 2,
            width: size,
            height: size)
        let bl = CGRect(
            x: Int(rect.bottomLeft.x) - size / 2,
            y: Int(rect.bottomLeft.y) - size / 2,
            width: size,
            height: size)
        
        

        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            
            self.detectionOverlay.sublayers = nil // remove all the old recognized objects
            self.detectionOverlay.addSublayer(self.createRoundedRectLayer(rect: tl, color: .red))
            self.detectionOverlay.addSublayer(self.createRoundedRectLayer(rect: tr, color: .green))
            self.detectionOverlay.addSublayer(self.createRoundedRectLayer(rect: br, color: .blue))
            self.detectionOverlay.addSublayer(self.createRoundedRectLayer(rect: bl, color: .yellow))
            self.updateLayerGeometry()
            
            CATransaction.commit()

        }
    }

    func createRoundedRectLayer(rect: CGRect, color: UIColor) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = rect
        shapeLayer.position = CGPoint(x: rect.midX, y: rect.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = color.cgColor
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

    
//    @discardableResult
//    func setupVision() -> NSError? {
//        // Setup Vision parts
//        let error: NSError! = nil
//
//        guard let modelURL = Bundle.main.url(forResource: "IndoorOutdoor", withExtension: "mlmodelc") else {
//            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
//        }
//        do {
//            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
//            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
//                DispatchQueue.main.async(execute: {
//                    // perform all the UI updates on the main queue
//                    if let results = request.results {
//                        let corners = cornersFromVisionResults(results)
//                        let correction
//                    }
//                })
//            })
//            self.requests = [objectRecognition]
//        } catch let error as NSError {
//            print("Model loading went wrong: \(error)")
//        }
//
//        return error
//    }
//
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }

}
