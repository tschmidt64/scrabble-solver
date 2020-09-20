//
//  ViewController.swift
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/13/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

import UIKit
import MobileCoreServices

enum ImageState {
    case normal
    case edited
}

class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    let images: [UIImage] =  (0...3).map { UIImage(named: "scrabble-\($0)")! }
    var curImageIdx = 0
    var curImageState = ImageState.normal
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var photoButton: UIButton! {
        didSet {
            photoButton.isEnabled = true // UIImagePickerController.isSourceTypeAvailable(.camera)
            photoButton.layer.cornerRadius = 10
            photoButton.clipsToBounds = true

        }
    }
    
    @IBAction func photoButtonPressed(_ sender: Any) {        
//        let picker = UIImagePickerController()
//        picker.sourceType = .camera
//        picker.mediaTypes = [kUTTypeImage as String]
//        picker.allowsEditing = false
//        picker.delegate = self
//        present(picker, animated: true)
        
        switch curImageState {
        case .normal:
            self.imageView.image = OpenCVWrapper.processImage(images[curImageIdx])
            curImageState = .edited
        case .edited:
            curImageIdx = (curImageIdx + 1) % images.count
            self.imageView.image = images[curImageIdx]
            curImageState = .normal
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = images[curImageIdx]
        // Do any additional setup after loading the view.
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        let alert = UIAlertController(title: "Hello", message: "CODE: \(OpenCVWrapper.openCVNumber())", preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//        print("ABout to present!")
//        self.present(alert, animated: true)
//
//    }

    
    // user hit cancel
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    // user took a photo
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            picker.presentingViewController?.dismiss(animated: true)
            self.imageView.image = OpenCVWrapper.processImage(image)
//            let storyboard = UIStoryboard(name: "Main", bundle: nil)
//            let pic = storyboard.instantiateViewController(withIdentifier: "ProcessImageController") as! ProcessImageController
//            pic.source_image = image
//            self.navigationController?.pushViewController(pic, animated: true)
        }
    }

    
}

