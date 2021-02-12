//
//  FrameExtractorViewController.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 11/28/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import UIKit
import Vision

class FrameExtractorViewController: UIViewController, FrameExtractorDelegate {
    
    @IBOutlet weak var imagePreviewView: UIImageView!
    var deviceOrientation: UIDeviceOrientation?
    var frameExtractor: FrameExtractor!
    var visionRequestDelegate: VNCoreMLRequester!
    var mostRecentQuad: Quadrilateral? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main, using: didRotate)
        self.deviceOrientation = UIDevice.current.orientation
        
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
        self.visionRequestDelegate = VNCoreMLRequester()
        
    }

    func didRotate(_ notification: Notification) {
        let newOrientation = UIDevice.current.orientation
        self.deviceOrientation = newOrientation.isFlat || newOrientation == .portraitUpsideDown
            ? self.deviceOrientation
            : UIDevice.current.orientation
        
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            print("landscape")
        case .portrait, .portraitUpsideDown:
            print("Portrait")
        default:
            print("other")
        }

    }
    var busy = false
    
    func captured(image: UIImage) {
        var result = image
        if let quad = mostRecentQuad {
            result = OpenCVWrapper.addRectangles(image, withTopLeft: quad.topLeft, withTopRight: quad.topRight, withBottomLeft: quad.bottomLeft, withBottomRight: quad.bottomRight)
        }
        // perform all the UI updates on the main queue
        DispatchQueue.main.async { [unowned self] in
            self.imagePreviewView.image = result
        }
        
        if busy { return }
        busy = true
        DispatchQueue.global(qos: .default).async {
            let orientation = self.deviceOrientation?.getUIImageOrientationFromUIDeviceOrientation() ?? .up
            let rotated = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: orientation)
            guard let cgImage = rotated.cgImage else { return }
            
            let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                let requests = try self.visionRequestDelegate.generateRequest(image: rotated) { objectObservations in
                    self.handleVisionResult(image: rotated, objectObservations: objectObservations)
                    self.busy = false
                }
                try imageRequestHandler.perform(requests)
            } catch {
                print(error)
            }
        }
    }
    
    func handleVisionResult(image: UIImage, objectObservations: [VNRecognizedObjectObservation]) {

        
        let cornerBBoxes = objectObservations.map { VNImageRectForNormalizedRect($0.boundingBox, Int(image.size.width), Int(image.size.height)) }
        
        let filteredCornerBoxes = cornerBBoxes.enumerated()
            .filter { i, box1 in
                // only take last intersecting bounding box
                !cornerBBoxes[(i + 1)...].contains{ box2 in box1.intersects(box2)}
                    
            }.map { $1 }
        
        if filteredCornerBoxes.count != 4 {
            mostRecentQuad = nil
            return
        }
        print("Got result!")
        
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
        
        mostRecentQuad = quad
        
//        let size = 24
//        let y = Int(image.size.height - (quad.topLeft.y - CGFloat(size / 2)))
//        let tlRect = CGRect(
//            x: Int(quad.topLeft.x) - size / 2,
//            y: Int(image.size.height - (quad.topLeft.y - CGFloat(size / 2))),
//            width: size,
//            height: size)
//        let trRect = CGRect(
//            x: Int(quad.topRight.x) - size / 2,
//            y: Int(image.size.height - (quad.topRight.y - CGFloat(size / 2))),
//            width: size,
//            height: size)
//        let brRect = CGRect(
//            x: Int(quad.bottomRight.x) - size / 2,
//            y: Int(image.size.height - (quad.bottomRight.y - CGFloat(size / 2))),
//            width: size,
//            height: size)
//        let blRect = CGRect(
//            x: Int(quad.bottomLeft.x) - size / 2,
//            y: Int(image.size.height - (quad.bottomLeft.y - CGFloat(size / 2))),
//            width: size,
//            height: size)
//
                
    }

    
}

fileprivate extension UIDeviceOrientation {
    func getUIImageOrientationFromUIDeviceOrientation() -> UIImage.Orientation {
        // return CGImagePropertyOrientation based on Device Orientation
        // This extented function has been determined based on experimentation with how an UIImage gets displayed.
        switch self {
        case .portrait, .faceUp: return .up
        case .portraitUpsideDown, .faceDown: return .up
        case .landscapeLeft: return .left // this is the base orientation
        case .landscapeRight: return .right
        case .unknown: return .up
        default:
            print("OOPS default")
            return .up
        }
    }
}
