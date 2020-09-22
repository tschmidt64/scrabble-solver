//
//  VisionRequest.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/22/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import AVFoundation
import Vision

extension UIViewController {
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


}
