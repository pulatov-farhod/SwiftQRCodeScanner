//
//  SwiftQRScanner.swift
//  SwiftQRScanner
//
//  Created by Vinod Jagtap on 12/5/17.
//

import UIKit
import CoreGraphics
import AVFoundation

/*
 This protocol defines methods which get called when some events occures.
 */
public protocol QRScannerCodeDelegate: class {
    
    func qrScanner(_ controller: UIViewController, scanDidComplete result: String)
    func qrScannerDidFail(_ controller: UIViewController,  error: String)
    func qrScannerDidCancel(_ controller: UIViewController)
}

/*
 QRCodeScannerController is ViewController which calls up method which presents view with AVCaptureSession and previewLayer
 to scan QR and other codes.
 */

public class QRCodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationBarDelegate, UINavigationControllerDelegate {
    
    public var loc: String = "ru"
    var squareView: SquareView? = nil
    public weak var delegate: QRScannerCodeDelegate?
    private var flashButton: UIButton? = nil
    
    //Extra images for adding extra features
    public var cameraImage: UIImage? = nil
    public var cancelImage: UIImage? = nil
    public var flashOnImage: UIImage? = nil
    public var flashOffImage: UIImage? = nil
    
    //Default Properties
    private let bottomSpace: CGFloat = 80.0
    private let spaceFactor: CGFloat = 16.0
    private let devicePosition: AVCaptureDevice.Position = .back
    private var delCnt: Int = 0
    
    //This is for adding delay so user will get sufficient time for align QR within frame
    private let delayCount: Int = 15
    
    //Initialise CaptureDevice
    lazy var defaultDevice: AVCaptureDevice? = {
        if let device = AVCaptureDevice.default(for: .video) {
            return device
        }
        return nil
    }()
    
    //Initialise front CaptureDevice
    lazy var frontDevice: AVCaptureDevice? = {
        if #available(iOS 10, *) {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                //device.focusMode
                return device
            }
        } else {
            for device in AVCaptureDevice.devices(for: .video) {
                if device.position == .front { return device }
            }
        }
        return nil
    }()
    
    //Initialise AVCaptureInput with defaultDevice
    lazy var defaultCaptureInput: AVCaptureInput? = {
        if let captureDevice = defaultDevice {
            do {
                return try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }()
    
    //Initialise AVCaptureInput with frontDevice
    lazy var frontCaptureInput: AVCaptureInput?  = {
        if let captureDevice = frontDevice {
            do {
                return try AVCaptureDeviceInput(device: captureDevice)
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }()
    
    lazy var dataOutput = AVCaptureMetadataOutput()
    
    //Initialise capture session
    lazy var captureSession = AVCaptureSession()
    
    //Initialise videoPreviewLayer with capture session
    lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        //layer.videoGravity =
        layer.cornerRadius = 10.0
        return layer
    }()
    
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    //Convinience init for adding extra images (camera, torch, cancel)
    convenience public init(cameraImage: UIImage?, cancelImage: UIImage?, flashOnImage: UIImage?, flashOffImage: UIImage?) {
        self.init()
        self.cameraImage = cameraImage
        self.cancelImage = cancelImage
        self.flashOnImage = flashOnImage
        self.flashOffImage = flashOffImage
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("SwiftQRScanner deallocating...")
    }
    
    //MARK: Life cycle methods
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //Currently only "Portraint" mode is supported
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        delCnt = 0
        prepareQRScannerView(self.view)
        startScanningQRCode()
        
    }
    
    /* This calls up methods which makes code ready for scan codes.
     - parameter view: UIView in which you want to add scanner.
     */
    
    
    func prepareQRScannerView(_ view: UIView) {
        setupCaptureSession(devicePosition) //Default device capture position is rear
        addViedoPreviewLayer(view)
        createCornerFrame()
        addButtons(view)
        
        turnOnFocus()
    }
    
    func turnOnFocus() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

           if device.hasTorch {
               do {
                   try device.lockForConfiguration()

                    device.focusPointOfInterest = CGPoint(x:0.5,y:0.45)
                device.exposureMode = .continuousAutoExposure
                device.focusMode = .continuousAutoFocus
                    //device.focusMode  = .autoFocus
                    device.unlockForConfiguration()
               } catch {
                   print("test text")
               }
           } else {
               print("focus")
           }
    }
    
    //Creates corner rectagle frame with green coloe(default color)
    func createCornerFrame() {
        let width: CGFloat = 200.0
        let height: CGFloat = 200.0
        
        let rect = CGRect.init(
            origin: CGPoint.init(
                x: self.view.frame.midX - width/2,
                y: self.view.frame.midY - (width+bottomSpace)/2),
            size: CGSize.init(width: width, height: height))
        
        dataOutput.rectOfInterest = CGRect.init(x:0.2, y:0.2, width: 0.6, height: 0.6)
        //dataOutput.rectOfInterest = self.convertRectOfInterest(rect: rect)
        print(dataOutput.rectOfInterest)

        
        self.squareView = SquareView(frame: rect)
        if let squareView = squareView {
            self.view.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            squareView.autoresizingMask = UIView.AutoresizingMask(rawValue: UInt(0.0))
            self.view.addSubview(squareView)
            
            addMaskLayerToVideoPreviewLayerAndAddText(rect: rect)
        }
        
       
    }
    
    func addMaskLayerToVideoPreviewLayerAndAddText(rect: CGRect) {
        let maskLayer = CAShapeLayer()
        maskLayer.frame = view.bounds
        maskLayer.fillColor = UIColor(white: 0.0, alpha: 0.5).cgColor
        let path = UIBezierPath(rect: rect)
        path.append(UIBezierPath(rect: view.bounds))
        maskLayer.path = path.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        view.layer.insertSublayer(maskLayer, above: videoPreviewLayer)
        
        let noteText = CATextLayer()
        noteText.fontSize = 15.0
        noteText.isWrapped=true
        if loc == "tj" {
         noteText.string = "Рамзи QR-ро дар чорчӯбаи скан ҷойгир кунед"
        } else { 
         noteText.string = "Поместите QR-код в рамку для сканирования"
        }
        noteText.alignmentMode = CATextLayerAlignmentMode.center
        noteText.contentsScale = UIScreen.main.scale
        noteText.frame = CGRect(x: spaceFactor, y: rect.origin.y + rect.size.height + 30, width: view.frame.size.width - (2.0 * spaceFactor), height: 22)
        noteText.foregroundColor = UIColor.white.cgColor
        view.layer.insertSublayer(noteText, above: maskLayer)
    }
    
    // Adds buttons to view which can we used as extra fearures
    private func addButtons(_ view: UIView) {
        
        let height: CGFloat = 44.0
        let width: CGFloat = 44.0
        let btnWidthWhenCancelImageNil: CGFloat = 200.0
        
        //Cancel button
        let cancelButton = UIButton()
        if let cancelImg = cancelImage {
            cancelButton.frame = CGRect(
                x: view.frame.width/2 - width/2,
                y: view.frame.height - 130,
                width: width,
                height: height)
            cancelButton.setImage(cancelImg, for: .normal)
        } else {
            cancelButton.frame = CGRect(
                x: view.frame.width/2 - btnWidthWhenCancelImageNil/2,
                y: view.frame.height - 130,
                width: btnWidthWhenCancelImageNil,
                height: height)
         if loc == "tj" {
             cancelButton.setTitle("Бе кор кардан", for: .normal)
         } else { 
            cancelButton.setTitle("Отмена", for: .normal)
            
         }
        }
        cancelButton.contentMode = .scaleAspectFit
        cancelButton.addTarget(self, action: #selector(dismissVC), for:.touchUpInside)
        view.addSubview(cancelButton)
        
        let UploadImg = UIButton()
        
//        UploadImg.frame = CGRect( x: view.frame.width/6,
//                       y: view.frame.height - 80,
//                       width: btnWidthWhenCancelImageNil,
//                       height: height)
        UploadImg.frame = CGRect(x: view.frame.width/2-btnWidthWhenCancelImageNil/2, y: view.frame.height - 180, width: 200, height: 40)
        if loc == "tj" {
         UploadImg.setTitle("Боргирии QR аз галерея", for: .normal)
        } else {
         UploadImg.setTitle("Загрузить", for: .normal)
        }
//        UploadImg.setTitleColor(UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1.00), for: .normal)
        UploadImg.contentMode = .scaleToFill
        UploadImg.addTarget(self, action: #selector(openGallery), for:.touchUpInside)
        UploadImg.backgroundColor=UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1.00)
        view.addSubview(UploadImg)
        
        let LighterBtn = UIButton()
            
        LighterBtn.frame = CGRect(x:40, y:40,  width: 90, height: 40)
//        LighterBtn.setTitle("light", for: .normal)
//        UploadImg.setTitleColor(UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1.00), for: .normal)
        LighterBtn.contentMode = .scaleToFill
//        LighterBtn.titleLabel?.font = UIFont(name: "Font Awesome 6 Free", size: 20)
        if loc == "tj" {
         LighterBtn.setTitle("Чароғак", for: .normal)
        } else { 
         LighterBtn.setTitle("Фонарик", for: .normal)
        }
        LighterBtn.addTarget(self, action: #selector(lightOffOn), for:.touchUpInside)
        LighterBtn.backgroundColor=UIColor(red: 0.15, green: 0.16, blue: 0.15, alpha: 1.00)
        view.addSubview(LighterBtn)
    
        //Torch button
        if let flashOffImg = flashOffImage {
            let flashButtonFrame = CGRect(x: 16, y: self.view.bounds.size.height - (bottomSpace + height + 10), width: width, height: height)
            flashButton = createButtons(flashButtonFrame, height: height)
            flashButton!.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
            flashButton!.setImage(flashOffImg, for: .normal)
            view.addSubview(flashButton!)
        }
        
        
        //Camera button
        if let cameraImg = cameraImage {
            let frame = CGRect(x: self.view.bounds.width - (width + 16), y: self.view.bounds.size.height - (bottomSpace + height + 10), width: width, height: height)
            let cameraSwitchButton = createButtons(frame, height: height)
            cameraSwitchButton.setImage(cameraImg, for: .normal)
            cameraSwitchButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
            view.addSubview(cameraSwitchButton)
        }
    }
    
    func createButtons(_ frame: CGRect, height: CGFloat) -> UIButton {
        let button = UIButton()
        button.frame = frame
        button.tintColor = UIColor.white
        button.layer.cornerRadius = height/2
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.contentMode = .scaleAspectFit
        return button
    }
    
    //Toggle torch
    @objc func toggleTorch() {
        //If device postion is front then no need to torch
        if let currentInput = getCurrentInput() {
            if currentInput.device.position == .front { return }
        }
        
        guard  let defaultDevice = defaultDevice else {return}
        if defaultDevice.isTorchAvailable {
            do {
                try defaultDevice.lockForConfiguration()
                defaultDevice.torchMode = defaultDevice.torchMode == .on ? .off : .on
                if defaultDevice.torchMode == .on {
                    if let flashOnImage = flashOnImage {
                        flashButton!.setImage(flashOnImage, for: .normal)
                    }
                } else {
                    if let flashOffImage = flashOffImage {
                        flashButton!.setImage(flashOffImage, for: .normal)
                    }
                }
                
                defaultDevice.unlockForConfiguration()
            } catch let error as NSError {
                print(error)
            }
        }
    }
    
    //Switch camera
    @objc func switchCamera() {
        if let frontDeviceInput = frontCaptureInput {
            captureSession.beginConfiguration()
            if let currentInput = getCurrentInput() {
                captureSession.removeInput(currentInput)
                let newDeviceInput = (currentInput.device.position == .front) ? defaultCaptureInput : frontDeviceInput
                captureSession.addInput(newDeviceInput!)
            }
            captureSession.commitConfiguration()
        }
    }
    
    private func getCurrentInput() -> AVCaptureDeviceInput? {
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            return currentInput
        }
        return nil
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true, completion: nil)
        delegate?.qrScannerDidCancel(self)
    }
    
    var imagePicker = UIImagePickerController()
    
    @objc func openGallery(){
        
         if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
                    print("Button capture")
        
                    imagePicker.delegate = self
                    imagePicker.sourceType = .savedPhotosAlbum
                    imagePicker.allowsEditing = false
        
                    present(imagePicker, animated: true, completion: nil)
                }
       
    }
    var on:Bool = true
    @objc func lightOffOn(){
        guard let device = AVCaptureDevice.default(for: .video) else { return }

           if device.hasTorch {
               do {
                   try device.lockForConfiguration()

                   if on == true {
                       on = false
                       device.torchMode = .on
                   } else {
                       on = true
                       device.torchMode = .off
                   }

                   device.unlockForConfiguration()
               } catch {
                   print("test text")
               }
           } else {
               print("light is not available")
           }
    }
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("ccccccc")
        self.dismiss(animated: true, completion: {
            () -> Void in
            print("cance")
        })
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
                print("No image found")
                self.dismiss(animated: true, completion: {
                    () -> Void in
                    print("error")
                })
            return
            }
        
            // print out the image size as a test
            
        if image.parseQR().count == 0{
            delegate?.qrScannerDidFail(self, error: "not found qr")
        }
        if image.parseQR().count > 0{
            print("qr found")
            print(image.parseQR()[0])
           
            delegate?.qrScanner(self, scanDidComplete: image.parseQR()[0])
            /*
            delegate?.qrScanner(self, scanDidComplete: unwrapedStringValue)
            } else {
                delegate?.qrScannerDidFail(self, error: "Empty string found")
            */
        }
            self.dismiss(animated: true, completion: {
                () -> Void in
                //delegate?.qrScannerDidCancel(self)
                print("cancel")
            })
        
        captureSession.stopRunning()
        self.dismiss(animated: true, completion: nil)
        
    }
    //MARK: - Setup and start capturing session
    
    open func startScanningQRCode() {
        if captureSession.isRunning { return }
        captureSession.startRunning()
    }
    
    func convertRectOfInterest(rect: CGRect) -> CGRect {
        let screenRect = self.view.frame
        let screenWidth = screenRect.width
        let screenHeight = screenRect.height
        let newX = 1 / (screenWidth / rect.minX)
        let newY = 1 / (screenHeight / rect.minY)
        let newWidth = 1 / (screenWidth / rect.width)
        let newHeight = 1 / (screenHeight / rect.height)
        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    private func setupCaptureSession(_ devicePostion: AVCaptureDevice.Position) {
        if captureSession.isRunning { return }
        
        switch devicePosition {
        case .front:
            if let frontDeviceInput = frontCaptureInput {
                if !captureSession.canAddInput(frontDeviceInput) {
                    delegate?.qrScannerDidFail(self, error: "Failed to add Input")
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                captureSession.addInput(frontDeviceInput)
            }
            break
        case .back, .unspecified :
            if let defaultDeviceInput = defaultCaptureInput {
                if !captureSession.canAddInput(defaultDeviceInput) {
                    delegate?.qrScannerDidFail(self, error: "Failed to add Input")
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                captureSession.addInput(defaultDeviceInput)
                //captureSession
            }
            break
        default: print("Do nothing")
        }
        
        if !captureSession.canAddOutput(dataOutput) {
            delegate?.qrScannerDidFail(self, error: "Failed to add Output")
            self.dismiss(animated: true, completion: nil)
            return
        }
  
        
        captureSession.addOutput(dataOutput)
        
        dataOutput.metadataObjectTypes = [.qr] //dataOutput.availableMetadataObjectTypes
        dataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    }
    
    fileprivate func getRectOfInterest() -> CGRect {
                
        let width: CGFloat = 200
        let height: CGFloat = 200
        
        let x1 = view.frame.maxX - width/2
        let y1 = view.frame.maxY - height/2
        
        //let x2 = (x1/view.frame.size.width)
        //let y2 = (y1/(view.frame.size.height - bottomSpace))
        
        //let currentInput = getCurrentInput()
        
        //let w1 = view.frame.maxY //(width/videoPreviewLayer.frame.maxX)+x2
        //let h1 = height/view.frame.maxY
        
        
        let re = CGRect(x: x1, y: y1, width: width, height: height)
        
        print(re)
          
        return re
    }
    
    //Inserts layer to view
    private func addViedoPreviewLayer(_ view: UIView) {
        videoPreviewLayer.frame = CGRect(x:view.bounds.origin.x, y: view.bounds.origin.y, width: view.bounds.size.width, height: view.bounds.size.height - bottomSpace)
        
       
        //dataOutput.rectOfInterest = self.getRectOfInterest()
        view.layer.insertSublayer(videoPreviewLayer, at: 0)
        
        
        //captureSession.stopRunning()
        //dataOutput.rectOfInterest = self.getRectOfInterest()
        //captureSession.startRunning()
    }
    
    // This method get called when Scanning gets complete
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        for data in metadataObjects {
            let transformed = videoPreviewLayer.transformedMetadataObject(for: data) as? AVMetadataMachineReadableCodeObject
            if let unwraped = transformed {
                if view.bounds.contains(unwraped.bounds) {
                    delCnt = delCnt + 1
                    if delCnt > delayCount {
                        if let unwrapedStringValue = unwraped.stringValue {
                            delegate?.qrScanner(self, scanDidComplete: unwrapedStringValue)
                        } else {
                            delegate?.qrScannerDidFail(self, error: "Empty string found")
                        }
                        captureSession.stopRunning()
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
}
    

///Currently Scanner suppoerts only portrait mode.
///This makes sure orientation is portrait
extension QRCodeScannerController {
    //Make orientations to portrait
    
    override public var shouldAutorotate: Bool {
        return false
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return UIInterfaceOrientation.portrait
    }
}

extension UIImage {
    func parseQR() -> [String] {
        guard let image = CIImage(image: self) else {
            return []
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        let features = detector?.features(in: image) ?? []

        return features.compactMap { feature in
            return (feature as? CIQRCodeFeature)?.messageString
        }
    }
}
