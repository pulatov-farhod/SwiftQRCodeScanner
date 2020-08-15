//
//  ViewController.swift
//  SwiftQRScanner
//
//  Created by vinodiOS on 12/05/2017.
//  Copyright (c) 2017 vinodiOS. All rights reserved.
//

import UIKit
import SwiftQRScanner

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate{
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    var imagePicker = UIImagePickerController()

    @IBAction func OpenGallery(_ sender: Any) {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
                    print("Button capture")
        
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
        
            present(imagePicker, animated: true, completion: nil)
            print("Button2")
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("ccccccc")
        self.dismiss(animated: true, completion: {
            () -> Void in
            print("cance")
        })
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
                print("No image found")
                self.dismiss(animated: true, completion: {
                    () -> Void in
                    print("error qr")
                })
                return
            }
        
            // print out the image size as a test
        
            print(image.size)
        
    }
    /*
    func imagePickerController(_ picker: UIImagePickerController!, didFinishPickingImage image: UIImage!, editingInfo: NSDictionary!){
        self.dismiss(animated: true, completion: { () -> Void in
            print("xxxxxxxxx")
        })
        print("sssssssss")
        //img.image = image
    }
    */
    @IBAction func scanQRCode(_ sender: Any) {
        
        //QRCode scanner without Camera switch and Torch
        let scanner = QRCodeScannerController()
        
        //QRCode with Camera switch and Torch
        //let scanner = QRCodeScannerController(cameraImage: UIImage(named: "camera"), cancelImage: UIImage(named: "cancel"), flashOnImage: UIImage(named: "flash-on"), flashOffImage: UIImage(named: "flash-off"))
        scanner.delegate = self
        self.present(scanner, animated: true, completion: nil)
    }
}
    
    

extension ViewController: QRScannerCodeDelegate {
    func qrScanner(_ controller: UIViewController, scanDidComplete result: String) {
        print("result:\(result)")
    }
    
    func qrScannerDidFail(_ controller: UIViewController, error: String) {
        print("error:\(error)")
    }
    
    func qrScannerDidCancel(_ controller: UIViewController) {
        print("SwiftQRScanner did cancel")
    }
}

