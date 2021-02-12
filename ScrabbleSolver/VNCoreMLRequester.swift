//
//  VNCoreMLRequester.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 12/9/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import Vision

typealias VisionResultCallback = ([VNRecognizedObjectObservation]) -> Void

protocol VNCoreMLRequestDelegate: class {
    func generateRequest(image: UIImage, callback: @escaping VisionResultCallback) throws -> [VNRequest]
}

class VNCoreMLRequester: VNCoreMLRequestDelegate {
    func generateRequest(image: UIImage, callback: @escaping VisionResultCallback) throws -> [VNRequest] {
        // Setup Vision parts
        guard let modelURL = Bundle.main.url(forResource: "IndoorOutdoor", withExtension: "mlmodelc") else {
            throw NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        
        let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
        
        let objDetectionReq = VNCoreMLRequest(model: visionModel) { (request, error) in
            guard let results = request.results else {
                print("Failed to get vision results")
                return
            }
            let objectObservations = results.compactMap { $0 as? VNRecognizedObjectObservation }
            callback(objectObservations)
        }
        
        return [objDetectionReq]
    }
    
}
