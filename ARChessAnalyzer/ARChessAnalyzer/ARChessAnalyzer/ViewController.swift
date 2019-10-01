//
//  ViewController.swift
//  OpenCVtest
//
//  Created by Anav Mehta on 5/19/19.
//  Copyright © 2019 Anav Mehta. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import ImageIO
import ChessEngine



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, EngineManagerDelegate {
    let engineManager: EngineManager = EngineManager()
    private var bestMoveNext: String! = ""
    private var detectionOverlay: CALayer! = nil
    private var gameFen: String = "position fen rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq -"
    private var castling: String = "-"
    private var curColor: String = "w"
    private var fen: [[String]] = Array(repeating: Array(repeating: " ", count: 8), count: 8)
    private var fen_len: Int = 0
    private var row_fen: Int = 0
    private var col_fen: Int = 0
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    private var chessBoardLayer: CALayer! = nil
    private var banner:UILabel!
    private var bannerLayer: CALayer! = nil

    
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var session = AVCaptureSession()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    // Vision parts
    private var requests = [VNRequest]()
    
    private var detectedChessBoard:Bool = false
    private var segmentedChessBoard:Bool = false
    private var predictedChessBoard:Bool = false
    private var finishedAnalyzing: Bool = false
    private var chessBoardBoundingBox:CGRect = CGRect()
    private var button:UIButton!
    private var buttonLayer:CALayer!
    private var proceed:Bool = false
    private var fenStr:String!
    private var debug: Bool = false
    
    private let imageP:UIImage!=UIImage(named:"white_pawn-512.png")
    private let imageN:UIImage!=UIImage(named:"white_knight-512.png")
    private let imageB:UIImage!=UIImage(named:"white_bishop-512.png")
    private let imageR:UIImage!=UIImage(named:"white_rook-512.png")
    private let imageQ:UIImage!=UIImage(named:"white_queen-512.png")
    private let imageK:UIImage!=UIImage(named:"white_king-512.png")
    private let imagep:UIImage!=UIImage(named:"black_pawn-512.png")
    private let imagen:UIImage!=UIImage(named:"black_knight-512.png")
    private let imageb:UIImage!=UIImage(named:"black_bishop-512.png")
    private let imager:UIImage!=UIImage(named:"black_rook-512.png")
    private let imageq:UIImage!=UIImage(named:"black_queen-512.png")
    private let imagek:UIImage!=UIImage(named:"black_king-512.png")
    private let imageempty:UIImage!=UIImage(named:"")

    /*
    private let imageURLP:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_pawn-512.png")
    private let imageURLN:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_knight-512.png")
    private let imageURLB:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_bishop-512.png")
    private let imageURLR:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_rook-512.png")
    private let imageURLQ:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_queen-512.png")
    private let imageURLK:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/white_king-512.png")
    private let imageURLp:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_pawn-512.png")
    private let imageURLn:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_knight-512.png")
    private let imageURLb:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_bishop-512.png")
    private let imageURLr:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_rook-512.png")
    private let imageURLq:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_queen-512.png")
    private let imageURLk:URL!=URL(string:"https://cdn3.iconfinder.com/data/icons/chess-7/100/black_king-512.png")
    private let imageURLempty:URL!=URL(string:"") */
    private var matchedSquare: String = "empty"

   
    private var model: ChessPieceClassifierFP16!
    
    override func viewWillAppear(_ animated: Bool) {
        model = ChessPieceClassifierFP16()
    }


    /// - Tag: MLModelSetup
    lazy var boardClassificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: ChessBoardClassifier().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processBoardClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .scaleFit
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    private func processBoardClassifications(for request: VNRequest, error: Error?){
        DispatchQueue.main.async {
            guard let results = request.results else {
                print("Unable to classify image")
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                print("Nothing recognized")
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(1)
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    
                    return String(format: "(%.2f) %@", classification.confidence, classification.identifier)
                }
                let descriptionArr = descriptions[0].split{$0 == " "}.map(String.init)
                if(descriptionArr[1] == "chessboard") {
                    self.detectedChessBoard = true
                    return
                }
            }
        }
    }

    private func insertFen() {
        self.fen[self.row_fen][self.col_fen] = self.matchedSquare
        self.col_fen = self.col_fen+1
        if(self.col_fen == 8) {
            self.col_fen = 0
            self.row_fen = self.row_fen+1
        }
        if(self.row_fen == 8) {
            self.row_fen = 0
        }
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer.frame = self.view.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let connection =  self.previewLayer?.connection  {
            let currentDevice: UIDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection : AVCaptureConnection = connection
            if previewLayerConnection.isVideoOrientationSupported {
                switch (orientation) {
                case .portrait: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                case .landscapeRight: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                    break
                case .landscapeLeft: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                    break
                case .portraitUpsideDown: updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                    break
                default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                }
            }
        }
    }
 
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
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
    private func displayBoard() {
        var rects = [CGRect]()
        let size: CGFloat = 14.0
        var rect: CGRect!
        let colorW:UIColor = .white
        //let colorB:UIColor = .blue
        let colorG:UIColor = .green
        let colorR:UIColor = .red
        let colorBlack:UIColor = .black
        let colorLB:UIColor = UIColor(red: 0, green: 1, blue: 1, alpha: 1.0)

        let (srow, scol, erow, ecol) = translateMove(move: bestMoveNext)
        CATransaction.begin()
        detectionOverlay.sublayers = nil
        CATransaction.commit()
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size*8.5, height: size*10), false, 0)
        let attrsS = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 5),
            NSAttributedString.Key.foregroundColor: UIColor.blue]
        let startingValue = Int(("a" as UnicodeScalar).value)
        rect = CGRect(x: CGFloat(0.0), y:  CGFloat(8.0)*size, width: size/2,  height: size/2)
        colorW.setFill()
        UIRectFill(rect)
        for i in 0...7 {
            rect = CGRect(x: CGFloat(0.0), y: size*CGFloat(i), width: size/2,  height: size)
            colorW.setFill()
            UIRectFill(rect)
            String(8-i).draw(at: CGPoint(x: size/8, y: size*CGFloat(i)+size/4),withAttributes: attrsS)
            
            
            rect = CGRect(x: size*CGFloat(i) + size/2, y:  CGFloat(8.0)*size, width: size,  height: size/2)
            colorW.setFill()
            UIRectFill(rect)
            String(UnicodeScalar(i + startingValue)!).draw(at: CGPoint(x: size*CGFloat(i)+3*size/4, y: CGFloat(8.125)*size),withAttributes: attrsS)
        }
        
        for i in 0...7 {
            for j in 0...7 {
                rect = CGRect(x: size*CGFloat(j)+size/2, y: size*CGFloat(i), width: size,  height: size)
                
                if((i + j) % 2 == 0) {colorW.setFill()}
                else {colorLB.setFill()}
                if(i == srow && j == scol) {colorG.setFill()}
                if(i == erow && j == ecol) {colorR.setFill()}
                UIRectFill(rect)
                if(fen[i][j] == "empty" || fen[i][j] == "") {continue}
                var sq:String=fen[i][j]
                let start = sq.index(sq.startIndex, offsetBy: 1)
                if(sq.prefix(1) == "b") {
                    sq = sq[start..<sq.endIndex].lowercased()
                } else {
                    sq = sq[start..<sq.endIndex].uppercased()
                }
                
                /*
                let imageURL: URL = piecestoURLhash(str: sq)
                if (imageURL == URL(string:"")) {continue}
                let data = (try? Data( contentsOf:imageURL))!*/
                let image2: UIImage = piecestoimagehash(str: sq)
                //let image2:UIImage! = UIImage(data: data)
                
                image2.draw(in: rect)
                rects.append(rect)
                
            }
        }
        let attrs = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 5),
            NSAttributedString.Key.foregroundColor: UIColor.red]
        rect = CGRect(x: CGFloat(0.0), y: CGFloat(8.5)*size, width: CGFloat(8.5)*size, height: CGFloat(1.0)*size)
        colorW.setFill()
        UIRectFill(rect)
        gameFen.draw(in: rect, withAttributes: attrs)
        rect = CGRect(x: CGFloat(0.0), y: CGFloat(9.5)*size, width: CGFloat(8.5)*size, height: CGFloat(0.5)*size)
        colorW.setFill()
        UIRectFill(rect)
        var moveStr:String! = "Best move: " + bestMoveNext!
        if(bestMoveNext == "(none)") {
            moveStr = "White wins!"
            if(curColor == "w") {moveStr = "Black wins!"}
        }
        if(bestMoveNext != "") {
            moveStr.draw(in: rect, withAttributes: attrs)
        }
        
        if(bestMoveNext != "") {
            
            let arrow = UIBezierPath()
            arrow.addArrow(start: CGPoint(x: CGFloat(Float(scol)+1.0)*size, y: CGFloat(Float(srow)+0.5)*size), end: CGPoint(x: CGFloat(Float(ecol)+1.0)*size, y: CGFloat(Float(erow)+0.5)*size), pointerLineLength: 5, arrowAngle: CGFloat(Double.pi / 4))
            colorBlack.setStroke()
            arrow.lineWidth = 1
            arrow.stroke()
            arrow.close()
        }
        
        guard let drawnImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print( "Error there was an issue, please try again")
            return
        }
        UIGraphicsEndImageContext()
        changeLabel()
        displayBoardOverlay(image: drawnImage)
        changeButton()
        repeat{
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
        } while (proceed == false)
        if(curColor == "w"){curColor = "b"}
        else {curColor = "w"}
    }
    func endCapture() {
        finishedAnalyzing = false
        engineManager.gameFen = gameFen
        engineManager.startAnalyzing()
        let time = DispatchTime.now() + DispatchTimeInterval.seconds(2)
        DispatchQueue.global().asyncAfter(deadline: time, execute: {
                self.engineManager.stopAnalyzing()
        })
        repeat{
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
        } while (finishedAnalyzing == false)

    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectedChessBoard = false
        segmentedChessBoard = false
        predictedChessBoard = false
        proceed = false
        var squareImage: UIImage!
        self.fen = Array(repeating: Array(repeating: "empty", count: 8), count: 8)
        self.row_fen = 0
        self.col_fen = 0
        let exifOrientation = exifOrientationFromDeviceOrientation()
        var image: UIImage!


        changeLabel()
        image = CameraUtil.imageFromSampleBuffer(buffer: sampleBuffer)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self).")}
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage,orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform([self.boardClassificationRequest])
        } catch {
                print(error)
        }
        if(!detectedChessBoard){return}
        changeLabel()
        image = image.rotate(radians: Float.pi/Float(2))
        var found: UIImage!=ImageConverter.detectChessBoard(image);
        if(found == nil) {return}
        found = found.rotate(radians: -Float.pi/Float(2))
        displayImageOverlay(image: found)
        segmentedChessBoard = true
        changeLabel()
        let openCvimage: NSMutableArray = ImageConverter.convert(image)

        for i in 0...63 {
            squareImage = openCvimage[i] as? UIImage
            matchedSquare = "empty"
            let pixelBuffer = squareImage.buffer()!
            guard let prediction = try? model.prediction(data: pixelBuffer) else {
                print("prediction error")
                return
            }
            matchedSquare = prediction.classLabel
            insertFen()
        }
        fenStr = get_fen(arr:fen)
        bestMoveNext = ""
        gameFen="position fen "+fenStr+" "+curColor+" "+castling+" -"
        print(gameFen)
        predictedChessBoard = true
        if(isValidBoard(fen: fenStr) || debug) {
            endCapture()
        }
        displayBoard()
    }
    func isValidBoard(fen: String) -> Bool {
        var foundBKing, foundWKing: Int
        foundBKing = 0
        foundWKing = 0
        
        for character in fen {
            if(character == "K") {foundWKing = foundWKing+1}
            if(character == "k") {foundBKing = foundBKing+1}
        }
        if((foundWKing == 1) && (foundBKing == 1)) {return true}
        return(false)
    }
    
    private func piecestoimagehash(str: String) -> UIImage {
        if(str == "R") {return imageR}
        if(str == "r") {return imager}
        if(str == "p") {return imagep}
        if(str == "P") {return imageP}
        if(str == "K") {return imageK}
        if(str == "k") {return imagek}
        if(str == "q") {return imageq}
        if(str == "Q") {return imageQ}
        if(str == "n") {return imagen}
        if(str == "N") {return imageN}
        if(str == "b") {return imageb}
        if(str == "B") {return imageB}
        return imageK
        
    }
    /*
    private func piecestoURLhash(str: String) -> URL {
        if(str == "R") {return imageURLR}
        if(str == "r") {return imageURLr}
        if(str == "p") {return imageURLp}
        if(str == "P") {return imageURLP}
        if(str == "K") {return imageURLK}
        if(str == "k") {return imageURLk}
        if(str == "q") {return imageURLq}
        if(str == "Q") {return imageURLQ}
        if(str == "n") {return imageURLn}
        if(str == "N") {return imageURLN}
        if(str == "b") {return imageURLb}
        if(str == "B") {return imageURLB}
        return imageURLK
        
    }*/
 
    @objc func buttonAction(sender: UIButton!) {
        proceed = true
        CATransaction.begin()
        buttonLayer.removeFromSuperlayer()
        chessBoardLayer.removeFromSuperlayer()
        CATransaction.commit()
    }

    private func changeButton() {
        DispatchQueue.main.async {
            CATransaction.begin()
            self.rootLayer.addSublayer(self.buttonLayer)
            CATransaction.commit()
        }
    }
    
    private func changeLabel() {
        DispatchQueue.main.async {
            CATransaction.begin()
            self.bannerLayer.removeFromSuperlayer()
            self.banner.text = "Detecting Chessboard..."
            if(self.detectedChessBoard) {
                self.banner.text = "Chessboard detected now segmenting..."
                self.detectedChessBoard = false
            } else if(self.segmentedChessBoard){
                self.banner.text = "Chessboard segmented now analyzing..."
                self.segmentedChessBoard = false
            } else if(self.predictedChessBoard) {
                self.banner.text = ""
                self.predictedChessBoard = false
            }
            self.rootLayer.addSublayer(self.bannerLayer)
            CATransaction.commit()
        }

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for i in 0...7 {
            for j in 0...7 {
                fen[i][j] = "empty"
            }
        }
        fen[0][0] = "wr"
        fen[0][7] = "wr"
        fen[0][1] = "wn"
        fen[0][6] = "wn"
        fen[0][2] = "wb"
        fen[0][5] = "wb"
        fen[0][3] = "wq"
        fen[0][4] = "wk"
        
        fen[7][0] = "br"
        fen[7][7] = "br"
        fen[7][1] = "bn"
        fen[7][6] = "bn"
        fen[7][2] = "bb"
        fen[7][5] = "bb"
        fen[7][3] = "bq"
        fen[7][4] = "bk"

        for i in 0...7 {
            fen[6][i] = "bp"
            fen[1][i] = "wp"
        }

        button = UIButton()
        proceed = false
        button.backgroundColor = .blue
        button.setTitle("Continue", for: [])
        button.setTitleColor(.green, for: [])
        button.addTarget(self, action: #selector(self.buttonAction(sender:)), for: .touchUpInside)
        self.view.addSubview(button)
        buttonLayer = button.layer

        banner = UILabel()
        banner.font = UIFont.boldSystemFont(ofSize: 18.0)
        banner.textAlignment = .center
        banner.textColor = .blue
        banner.text = "Detecting Chessboard...."
        self.view.addSubview(banner)
        

        
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        banner.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 1.0).isActive = true
        banner.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.1).isActive = true
        banner.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        banner.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50).isActive = true
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        button.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.25).isActive = true
        button.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.05).isActive = true
        button.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -50).isActive = true
 
        
        bannerLayer = banner.layer

        setupAVCapture()
        engineManager.delegate = self
        engineManager.gameFen = gameFen

    }
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func startCaptureSession() {
        session.startRunning()
    }
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!

        // Select a video device, make an input
 
        
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        //session.sessionPreset = .vga640x480 // Model image size is smaller.
        //session.sessionPreset = .photo
        //session.sessionPreset = .hd1280x720
        session.sessionPreset = AVCaptureSession.Preset.high
        //session.sessionPreset = .hd4K3840x2160

        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = self.view.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
 
        setupLayers()
        updateLayerGeometry()
        
        // start the capture
        startCaptureSession()
    }
 

    func get_fen(arr: [[String]]) -> String {
        var fen: String = ""
        var fen_row: String = ""
        var prev_blanks: Int = 0
        var sq: String
        
        for row in 0...7{
            fen_row = ""
            prev_blanks = 0
            for col in 0...7 {
                sq = arr[row][col]
                if (sq == "empty" || sq == "" || sq == " ") {
                    prev_blanks = prev_blanks+1
                    if(col == 7) {
                        fen_row += String(prev_blanks)
                        prev_blanks = 0
                    }
                } else {
                    if(prev_blanks != 0) {fen_row += String(prev_blanks)}
                    prev_blanks = 0
                    let start = sq.index(sq.startIndex, offsetBy: 1)
                    if(sq.prefix(1) == "b") {
                        fen_row += sq[start..<sq.endIndex]
                    } else {
                        fen_row += sq[start..<sq.endIndex].uppercased()
                    }
                }
            }
            if(0 < row) {fen_row = "/" + fen_row}
            fen = fen + fen_row
        }
        return fen
    }
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
        chessBoardLayer = CALayer()
        chessBoardLayer.frame = rootLayer.bounds
        chessBoardLayer.contentsGravity = CALayerContentsGravity.center
    }
    func displayBoardOverlay(image: UIImage){
        CATransaction.begin()
        let myImage = image.cgImage
        chessBoardLayer.contents = myImage
        rootLayer.addSublayer(chessBoardLayer)
        CATransaction.commit()
    }
    func displayImageOverlay(image: UIImage){
        CATransaction.begin()
        detectionOverlay.sublayers = nil
        let myImage = image.cgImage
        let myLayer = CALayer()
        myLayer.frame = detectionOverlay.bounds
        myLayer.position = CGPoint(x: detectionOverlay.bounds.midX, y: detectionOverlay.bounds.midY)
        myLayer.contents = myImage
        detectionOverlay.addSublayer(myLayer)
        CATransaction.commit()
    }
    func translateMove(move: String) -> (Int,Int,Int,Int) {
        if((move == "") || (move == "(none)")) {return(-1,-1,-1,-1)}
        let tmpArry = Array(move)
        let scol: Int = Int(tmpArry[0].unicodeScalars.map{$0.value}[0]-"a".unicodeScalars.map{$0.value}[0])
        let srow: Int = Int(tmpArry[1].unicodeScalars.map{$0.value}[0]-"1".unicodeScalars.map{$0.value}[0])
        let ecol: Int = Int(tmpArry[2].unicodeScalars.map{$0.value}[0]-"a".unicodeScalars.map{$0.value}[0])
        let erow: Int = Int(tmpArry[3].unicodeScalars.map{$0.value}[0]-"1".unicodeScalars.map{$0.value}[0])
        return (7-srow, scol, 7-erow, ecol)
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
        //detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: scale))
        //detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat( 0.0)).scaledBy(x: scale, y: scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    

    // MARK: EngineManagerDelegate
    
    func engineManager(_ engineManager: EngineManager, didReceivePrincipalVariation pv: String) {
        print("PV: \(pv)")
    }
    
    func engineManager(_ engineManager: EngineManager, didUpdateSearchingStatus searchingStatus: String) {
        print("Searching status: \(searchingStatus)")
    }
    
    func engineManager(_ engineManager: EngineManager, didReceiveBestMove bestMove: String?, ponderMove: String?) {
        if let bestMove = bestMove {
            bestMoveNext = bestMove
            print("Best move is \(bestMove)")
            finishedAnalyzing = true
        } else {
            print("No available moves")
        }
    }
    
    func engineManager(_ engineManager: EngineManager, didAnalyzeCurrentMove currentMove: String, number: Int, depth: Int) {
        
    }
}

