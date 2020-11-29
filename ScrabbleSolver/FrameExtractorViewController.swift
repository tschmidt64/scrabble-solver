//
//  FrameExtractorViewController.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 11/28/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import UIKit

class FrameExtractorViewController: UIViewController, FrameExtractorDelegate {
    @IBOutlet weak var imagePreviewView: UIImageView!
    var deviceOrientation: UIDeviceOrientation?
    var frameExtractor: FrameExtractor!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main, using: didRotate)
        self.deviceOrientation = UIDevice.current.orientation
        
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
        
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

    
    func captured(image: UIImage) {
        let orientation = self.deviceOrientation?.getUIImageOrientationFromUIDeviceOrientation() ?? .up
        let rotated = UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: orientation)
        imagePreviewView.image = rotated

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
