import Foundation
import AVFoundation

@available(iOS 10.0, *)
@objc(CameraStream)
class CameraStream: CDVPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var mainCommand: CDVInvokedUrlCommand?
    var fi:CLong = 1;
    var fileManager:FileManager?
    var dir:URL?
    
    @objc(startCapture:)
    func startCapture(command: CDVInvokedUrlCommand) {
        mainCommand = command;
        fileManager = FileManager.default;
        do{
            try dir = fileManager!.url(for: FileManager.SearchPathDirectory.cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
        }catch let e as NSError {
            NSLog("error", e);
        }
        
        NSLog("dir " + dir!.absoluteString);
        // Selecting the camera from the device
        let cameraString = command.arguments[0] as? String ?? "front"
        var camera: AVCaptureDevice
        
        switch cameraString {
        case "back":
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)!
        default:
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)!
        }
        
        //camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 24);
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        var videoDataOutput: AVCaptureVideoDataOutput!
        
        // Setting up session
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSession.Preset.vga640x480;
        
        do{
            input = try AVCaptureDeviceInput(device: camera)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        if error == nil && session!.canAddInput(input){
            session!.addInput(input)
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            //this shit not working
            //videoDataOutput.connection(with: AVMediaType.video)?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
            
            // Setting single thread queue to silence xcode warning
            let queue = DispatchQueue.main//(label: "camerabase64")
            videoDataOutput.setSampleBufferDelegate(self, queue: queue)
            
            if session!.canAddOutput(videoDataOutput) {
                mainCommand = command
                session!.addOutput(videoDataOutput)
                // lets start some session baby :)
                session!.startRunning()
            }
        }
    }
    
    @objc(pause:)
    func pause(command: CDVInvokedUrlCommand){
        if session?.isRunning ?? false {
            session?.stopRunning()
        }
    }
    
    @objc(resume:)
    func resume(command: CDVInvokedUrlCommand){
        if session?.isRunning ?? false {
            return
        }
        session?.startRunning()
    }
    
    func SendData(bytesPointer: UnsafeRawPointer, size_: Int) {
        let data = Data(bytes: bytesPointer, count: size_ );
//        bytesPointer.deallocate();
        //let data = Data(bytes: baseAddress!, count: bytesPerRow*height);
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: data );
        //let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "data:image/jpeg;base64,)");
        //result?.associatedObject = data;
        result?.keepCallback = true;
        result!.setKeepCallbackAs(true);
        commandDelegate.send(result, callbackId: mainCommand?.callbackId);
    }
    
    func captureOutput(_ output: AVCaptureOutput,  didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        self.fi = self.fi+1;
        if (self.fi % 2 != 0) {return;}
        commandDelegate.run {
            autoreleasepool{
                let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                // Lock the base address of the pixel buffer
                CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
                
                // Get the number of bytes per row for the pixel buffer
                let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
                
                // Get the number of bytes per row for the pixel buffer
                let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
                // Get the pixel buffer width and height
                let width = CVPixelBufferGetWidth(imageBuffer!)
                let height = CVPixelBufferGetHeight(imageBuffer!)
                
                
                //let data:NSData = NSData(bytes: baseAddress!, length: bytesPerRow*height);
                
                // Create a device-dependent RGB color space
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                
                // Create a bitmap graphics context with the sample buffer data
                var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
                bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
                //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
                let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
                let quartzImage = context?.makeImage()
                
                // Unlock the pixel buffer
                CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
                
                // Create an image object from the Quartz image
                //let image = UIImage.init(cgImage: quartzImage!)
                let image = UIImage(cgImage: quartzImage!, scale: 1, orientation: UIImage.Orientation.up);
                let imageData = image.jpegData(compressionQuality: 0.6);
                //let imageData = UIImageJPEGRepresentation(image, 0.3)
                // Generating a base64 string for cordova's consumption
                let base64 = imageData?.base64EncodedString(options: Data.Base64EncodingOptions.endLineWithLineFeed)
                // Describe the function that is going to be call by the webView frame
                //let javascript = "cordova.plugins.CameraStream.capture('data:image/jpeg;base64,\(base64!)')"
                
                /*let fname = "tempfile" + String(self.fi % 50) + ".jpg";
                do {
                    try imageData?.write(to: URL(fileURLWithPath: fname, relativeTo: self.dir))
                    
                }catch let error1 as NSError {
                    NSLog("error", error1)
                }
                */
                
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "data:image/jpeg;base64,\(base64!)");
                //let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: (self.dir?.absoluteString.replacingOccurrences(of: "file:///", with: "http://localhost:8080/_file_/"))! + fname);
                result?.keepCallback = true;
                [self.commandDelegate.send(result, callbackId: self.mainCommand?.callbackId)];
                
                }// Unlock the pixel buffer
                //let data = NSData(bytes: baseAddress!, length: bytesPerRow*height);
                /*let bytesPointer = UnsafeMutableRawPointer.allocate(byteCount: 1638400, alignment: 1);
                 SendData(bytesPointer: bytesPointer, size_: 1638400);
                 //
                 //            let data = Data(bytes: bytesPointer, count: 638400 );
                 bytesPointer.deallocate();
                 //            //let data = Data(bytes: baseAddress!, count: bytesPerRow*height);
                 //            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: data );
                 //            //let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "data:image/jpeg;base64,)");
                 //            //result?.associatedObject = data;
                 //            result?.keepCallback = true;
                 //            result!.setKeepCallbackAs(true);
                 //            commandDelegate.send(result, callbackId: mainCommand?.callbackId);
                 CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)*/
            }
        }
        
    }


