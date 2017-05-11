//
//  ViewController.swift
//  VdoboxPOC
//
//  Created by Varun on 25/04/17.
//  Copyright © 2017 Diet Code. All rights reserved.
//

import UIKit
import Foundation
import AVKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet weak var videoTimerLabel: UILabel!
    @IBOutlet weak var videoSlider: UISlider! {
        didSet {
            self.videoSlider.addTarget(self, action: #selector(didStart(Tracking:)), for: .touchDown)
            self.videoSlider.addTarget(self, action: #selector(didFinish(Tracking:)), for: .touchUpInside)
            self.videoSlider.addTarget(self, action: #selector(didChange(Value:)), for: .valueChanged)
            self.videoSlider.minimumTrackTintColor = UIColor(colorLiteralRed: 227.0/255.0, green: 76.0/255.0, blue: 65.0/255.0, alpha: 1.0)
            self.videoSlider.maximumTrackTintColor = UIColor.gray
            self.videoSlider.thumbTintColor = UIColor(colorLiteralRed: 227.0/255.0, green: 76.0/255.0, blue: 65.0/255.0, alpha: 1.0)
        }
    }
    @IBOutlet weak var playButton: UIBarButtonItem! {
        didSet {
            playButton.target = self
            playButton.action = #selector(playVideo)
        }
    }
    @IBOutlet weak var pauseButton: UIBarButtonItem! {
        didSet {
            pauseButton.target = self
            pauseButton.action = #selector(pauseVideo)
        }
    }
    
    // MARK: Public API's
    
    // MARK: Private API's
    fileprivate var player: AVPlayer?
    fileprivate var asset: AVAsset?
    fileprivate var playerItem: AVPlayerItem?
    fileprivate var playerItemContext: AVPlayerItem?
    fileprivate var playerLayer: AVPlayerLayer?
    fileprivate var PlayerMetadataLayer: CALayer?
    fileprivate var boundryStartTimeObserverToken: Any?
    fileprivate var boundryEndTimeObserverToken: Any?
    fileprivate var periodicIntervalTimeObserver: Any?
    fileprivate var playerItemMetadata: [[String: AnyObject]] = []
    fileprivate var playerItemDisplayedMetadata: [[String: AnyObject]] = []
    fileprivate var isVideoPlaying: Bool = false
    fileprivate var wasVideoPlaying: Bool = false
    fileprivate var isReadyToPlay: Bool = false {
        willSet {
            if newValue {
                self.videoSlider.isEnabled = true
                self.videoSlider.alpha = 1.0
                let totalDuration = CMTimeGetSeconds(self.player?.currentItem?.duration ?? CMTimeMake(Int64(0), Int32(0)))
                let currentDuration = CMTimeGetSeconds(self.player?.currentTime() ?? CMTimeMake(Int64(0), Int32(0)))
                self.videoTimerLabel.text = "\(String(format: "%.2f", currentDuration))/\(String(format: "%.2f", totalDuration))"
            } else {
                self.videoSlider.isEnabled = false
                self.videoSlider.alpha = 0.7
                self.videoTimerLabel.text = "0.00/0.00"
            }
        }
    }
    fileprivate let playerItemURL: URL = URL(string: "https://res.cloudinary.com/vdobox/video/upload/v1491284125/hyxqi2yoedoh9ti4dvd8.mp4")!
    fileprivate let playerItemMetadataURL: URL = URL(string: "https://vdobox-api.herokuapp.com/api/v1/videoeditors?videoID=58f8a23214656a11005281ce")!
    
    // MARK: Life Cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupUI()
        fetchPlayerMetaData()
        //initiatePlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let playR = self.player, let obsEndTime = self.boundryEndTimeObserverToken, let obsStartTime = self.boundryStartTimeObserverToken, let obsPeriodicObserver = self.periodicIntervalTimeObserver else {
            return
        }
        playR.removeTimeObserver(obsEndTime)
        playR.removeTimeObserver(obsStartTime)
        playR.removeTimeObserver(obsPeriodicObserver)
        //let _ = String(format: "%.2f", self.player?.currentItem?.duration as CVarArg? ?? 0.00)
        //let _ = String(format: "%.2f", self.player?.currentTime() as CVarArg? ?? 0.00)
    }
    
    // MARK: Utility Methods
    
    fileprivate func setupUI() {
        if isReadyToPlay {
            videoSlider.alpha = 0.7
            videoSlider.isEnabled = false
        }
    }
    
    
    fileprivate func fetchPlayerMetaData() {
        var request = URLRequest(url: playerItemMetadataURL)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            // code
            if error != nil {
                //some error occoured
                print("\(Bundle.main.bundleIdentifier!)_ERROR: \(error!)")
            } else {
                guard let _ = response else {
                    return
                }
                //print("\(Bundle.main.bundleIdentifier!)_RESPONSE: \(res)")
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: AnyObject]
                    //print("\(Bundle.main.bundleIdentifier!)_JSON_DATA: \(jsonData)")
                    if let json = jsonData {
                        guard let results = json["results"] as? [[String: AnyObject]] else {
                            return
                        }
                        var holderArray: [[String: AnyObject]] = []
                        for index in 0..<results.count {
                            var metaData: [String: AnyObject] = [:]
                            metaData = results[index]
                            metaData["isDisplayed"] = false as AnyObject?
                            metaData["tag"] = index as AnyObject
                            
                            //print("\(Bundle.main.bundleIdentifier!)_METADATA_OBJECT: \(metaData)")
                            holderArray.append(metaData)
                        }
                        holderArray.sort(by: { (element0, element1) -> Bool in
                            guard let startTime0 = element0["startSecond"] as? Int else {
                                return false
                            }
                            guard let startTime1 = element1["startSecond"] as? Int else {
                                return false
                            }
                            return startTime0 < startTime1
                        })
                        self.playerItemMetadata = holderArray
                        print("\(Bundle.main.bundleIdentifier!)_METADATA_ARRAY: \(self.playerItemMetadata)")
                        DispatchQueue.main.async {
                            self.initiatePlayer()
                        }
                    }
                } catch {
                    print("\(Bundle.main.bundleIdentifier!)_JSON_ERROR: \(error)");
                }
            }
        }.resume()
    }
    
    fileprivate func initiatePlayer() {
        let endPoints = self.playerItemMetadata.map { (object) -> NSValue in
            let endTime = object["endSecond"] as? Int ?? 0
            return NSValue(time: CMTimeMake(Int64(endTime), Int32(1)))
        }
        let startPoints = self.playerItemMetadata.map { (object) -> NSValue in
            let startTime = object["startSecond"] as? Int ?? 0
            return NSValue(time: CMTimeMake(Int64(startTime), Int32(1)))
        }
        print("\(Bundle.main.bundleIdentifier!)_MAPPED_ARRAY: \(endPoints)")
        asset = AVAsset(url: playerItemURL)
        let assetKeys = ["playable"]
        
        playerItem = AVPlayerItem(asset: asset!, automaticallyLoadedAssetKeys: assetKeys)
        
        // add observer
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        
        // initialize player
        player = AVPlayer(playerItem: playerItem)
        
        let videoLayer = AVPlayerLayer(player: player)
        videoLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.width, height: self.view.frame.size.width)
        self.view.layer.addSublayer(videoLayer)
        self.playerLayer = videoLayer
        
        // handle when the time-frame for displaying a certain metadataLayer is over
        boundryStartTimeObserverToken = player?.addBoundaryTimeObserver(forTimes: startPoints, queue: nil, using: {
            [weak self] time in
            guard (self != nil), (self?.playerItemMetadata.count)! > 0 else {
                return
            }
            self?.displayData()
        })
        
        boundryEndTimeObserverToken = player?.addBoundaryTimeObserver(forTimes: endPoints, queue: nil, using: {
            [weak self] time in
            guard (self != nil), (self?.playerItemDisplayedMetadata.count)! > 0 else {
                return
            }
            self?.hideData()
        })
        
        periodicIntervalTimeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(Float64(1.0), Int32(NSEC_PER_SEC)), queue: nil, using: { (time) in
            // do something. Update UISlider
            guard let videoPlayer = self.player else {
                return
            }
            let itemDuration = CMTimeGetSeconds((videoPlayer.currentItem?.duration)!)
            let currentTime = CMTimeGetSeconds(videoPlayer.currentTime())
            let sliderValue = Float(currentTime / itemDuration)
            self.videoSlider.setValue(sliderValue, animated: false)
            self.videoTimerLabel.text = "\(String(format: "%.2f", currentTime))/\(String(format: "%.2f", itemDuration))"
        })
    }
    
    fileprivate func addPlayerMetadataLayer() {
        // check if a Item to play is avaliable, also that its metadat array contsins elements, to overlay
        guard let _ = self.playerItem, self.playerItemMetadata.count > 0, let videoLayer = self.playerLayer, let currentPlayerItem = self.player?.currentItem else {
            return
        }
        for layer in self.view.layer.sublayers! {
            if layer.isKind(of: AVSynchronizedLayer.classForCoder()) {
                layer.removeFromSuperlayer()
            }
        }
        
       // let syncLayer = AVSynchronizedLayer(playerItem: playerItem)
        let videoDisplayRect = videoLayer.videoRect
        let videoGravity = currentPlayerItem.asset.tracks(withMediaType: AVMediaTypeVideo)[0]
        let standardlayer = CALayer()
        standardlayer.frame = CGRect(x: videoLayer.frame.origin.x, y: videoLayer.frame.origin.y, width: videoLayer.frame.width, height: videoLayer.frame.height)
        standardlayer.backgroundColor = UIColor.clear.cgColor
        self.PlayerMetadataLayer = standardlayer
        
        for index in 0..<self.playerItemMetadata.count {
            
            var dataToDisplay = self.playerItemMetadata[index]
            let xCoordinate = ((CGFloat(dataToDisplay["x"] as? Int ?? 0) * videoDisplayRect.width) / videoGravity.naturalSize.width)
            let yCoordinate = ((CGFloat(dataToDisplay["y"] as? Int ?? 0) * videoDisplayRect.height) / videoGravity.naturalSize.height)
            let _ = CFTimeInterval(dataToDisplay["startSecond"] as? Int ?? 0) // start Time
            let _ = CFTimeInterval(dataToDisplay["endSecond"] as? Int ?? 0) // end Time
            
            let pinImage = UIImage(named: "pin")?.cgImage
            
            let dataLayer = CALayer()
            dataLayer.frame = CGRect(x: (videoDisplayRect.origin.x + xCoordinate), y: (videoDisplayRect.origin.y + yCoordinate), width: 30.0, height: 30.0)
            dataLayer.backgroundColor = UIColor.clear.cgColor
            dataLayer.contents = pinImage
            dataLayer.contentsGravity = kCAGravityResizeAspect
            dataLayer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            dataLayer.opacity = 0.0
            
            standardlayer.addSublayer(dataLayer)
            
            dataToDisplay["isDisplayed"] = false as AnyObject
            dataToDisplay["dataLayer"] = dataLayer as AnyObject
            
            self.playerItemMetadata.insert(dataToDisplay, at: index)
        }
        
        self.view.layer.addSublayer(standardlayer)
        
    }
    
    fileprivate func videoDidScrub(to playTime: Float) {
        let currentTime = playTime
        if self.playerItemMetadata.count > 0 {
            // element.startSecond < currentTime
            // element.endSecond > currentTime
            let elementsToDisplay = self.playerItemMetadata.filter({ (element) -> Bool in
                var valueToReturn = false
                if let startSecond = element["startSecond"] as? Float, startSecond < currentTime, let endSecond = element["endSecond"] as? Float, endSecond > currentTime, let layerToDisplay = element["dataLayer"] as? CALayer, layerToDisplay.opacity == 0.0 {
                    valueToReturn = true
                }
                return valueToReturn
            })
            for index in 0..<elementsToDisplay.count {
                var object = elementsToDisplay[index]
                object["isDisplayed"] = true as AnyObject
                let dataLayer = object["datalayer"] as? CALayer
                dataLayer?.opacity = 1.0
                
                // after toggling add the elements to the displayed array, and sort it in ascending order of 'endSecond'.
                self.playerItemDisplayedMetadata.append(object)
                self.playerItemDisplayedMetadata.sort(by: { (element0, element1) -> Bool in
                    guard let startTime0 = element0["endSecond"] as? Int else {
                        return false
                    }
                    guard let startTime1 = element1["endSecond"] as? Int else {
                        return false
                    }
                    return startTime0 < startTime1
                })
            }
        }
        
        if self.playerItemDisplayedMetadata.count > 0 {
            let elementsToHide = self.playerItemDisplayedMetadata.filter({ (element) -> Bool in
                var valueToReturn = false
                if let endSecond = element["endSecond"] as? Float, endSecond <= currentTime, let dataLayer = element["dataLayer"] as? CALayer, dataLayer.opacity == 1.0 {
                    valueToReturn = true
                }
                return valueToReturn
            })
            
            for index in 0..<elementsToHide.count {
                var object = elementsToHide[index]
                let objectIndex = self.playerItemDisplayedMetadata.index(where: { (element) -> Bool in
                    var valueToReturn = false
                    if let objectTag = object["tag"] as? Int, let elementTag = element["tag"] as? Int, objectTag == elementTag {
                        valueToReturn = true
                    }
                    return valueToReturn
                })
                object["isDisplayed"] = false as AnyObject
                let dataLayer = object["dataLayer"] as? CALayer
                dataLayer?.opacity = 0.0
                
                if let index = objectIndex {
                    self.playerItemDisplayedMetadata.remove(at: index)
                }
            }
        }
    }
    
    fileprivate func displayData() {
        guard self.playerItemMetadata.count > 0 else {
            return
        }
        
        let currentTime = Int(CMTimeGetSeconds((self.player?.currentTime())!))
        
        let elementsToDisplay = self.playerItemMetadata.filter({ (element) -> Bool in
            var valueToReturn = false
            if let startSecond = element["startSecond"] as? Int, startSecond == currentTime, let layerToDisplay = element["dataLayer"] as? CALayer, layerToDisplay.opacity == 0.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        
        for index in 0..<elementsToDisplay.count {
            var object = elementsToDisplay[index]
            object["isDisplayed"] = true as AnyObject
            let dataLayer = object["dataLayer"] as? CALayer
            dataLayer?.opacity = 1.0
            
            self.playerItemDisplayedMetadata.append(object)
            self.playerItemDisplayedMetadata.sort(by: { (element0, element1) -> Bool in
                guard let startTime0 = element0["endSecond"] as? Int else {
                    return false
                }
                guard let startTime1 = element1["endSecond"] as? Int else {
                    return false
                }
                return startTime0 < startTime1
            })
        }
    }
    
    fileprivate func hideData() {
        let currentTime = Int(CMTimeGetSeconds((self.player?.currentTime())!))
        
        let elementsToHide = self.playerItemDisplayedMetadata.filter({ (element) -> Bool in
            var valueToReturn = false
            if let endSecond = element["endSecond"] as? Int, endSecond == currentTime, let dataLayer = element["dataLayer"] as? CALayer, dataLayer.opacity == 1.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        
        for index in 0..<elementsToHide.count {
            var object = elementsToHide[index]
            let objectIndex = self.playerItemDisplayedMetadata.index(where: { (element) -> Bool in
                var valueToReturn = false
                if let objectTag = object["tag"] as? Int, let elementTag = element["tag"] as? Int, objectTag == elementTag {
                    valueToReturn = true
                }
                return valueToReturn
            })
            object["isDisplayed"] = false as AnyObject
            let dataLayer = object["dataLayer"] as? CALayer
            dataLayer?.opacity = 0.0
            
            if let objectInd = objectIndex {
                self.playerItemDisplayedMetadata.remove(at: objectInd)
            }
        }
    }
    
    // MARK: AVPlayer Controller Methods
    func playVideo() {
        guard let player = self.player, self.isReadyToPlay == true else {
            return
        }
        if (!isVideoPlaying) {
            isVideoPlaying = true
            player.play()
        }
    }
    
    func pauseVideo() {
        guard let player = self.player, self.isReadyToPlay == true else {
            return
        }
        if (isVideoPlaying) {
            isVideoPlaying = false
            player.pause()
        }
    }
    
    // MARK: Did Select Hotspot
    fileprivate func didSelectHotSpot(having metadata: [String: AnyObject]) {
        guard let videoPlayer = self.player, let startSecond = metadata["startSecond"] as? Int, let endSecond = metadata["endSecond"] as? Int else {
            return
        }
        let currentTime = Int(CMTimeGetSeconds(videoPlayer.currentTime()))
        if currentTime >= startSecond && currentTime <= endSecond {
            // the hotspot was visible when clicked
            print("DID SELECT HOTSPOT: \(metadata)")
        }
    }
    
    // MARK: Key Value Observing
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &playerItemContext {
            guard let statusNumber = change?[.newKey] as? NSNumber else {
                return
            }
            let status = AVPlayerItemStatus(rawValue: statusNumber.intValue)
            
            if status == .readyToPlay {
                // readyToPlay
                // player is ready to play, load metadata, start playing
                print("PLAYER READY TO PLAY")
                self.isReadyToPlay = true
                self.addPlayerMetadataLayer()
            } else if status == .failed {
                // failed
                print("PLAYER FAILED TO PLAY")
            } else {
                // unknown
                print("UNKNOWN PLAYER ERROR")
            }
            
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UISlider Methods
    
    @objc fileprivate func didStart(Tracking slider: UISlider) {
        guard let videoPlayer = self.player else {
            return
        }
        if videoPlayer.rate > 0 {
            wasVideoPlaying = true
        }
        self.pauseVideo()
    }
    
    @objc fileprivate func didFinish(Tracking slider: UISlider) {
        guard let videoPlayer = self.player, let itemPlaying = self.playerItem else {
            return
        }
        let itemDuration = CMTimeGetSeconds(itemPlaying.duration)
        let expectedTime = CMTimeMake(Int64(Float(itemDuration) * slider.value), Int32(1))
        
        videoPlayer.seek(to: expectedTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) { (status) in
            // do something
            if status {
                self.videoDidScrub(to: Float(CMTimeGetSeconds(expectedTime)))
                self.videoTimerLabel.text = "\(String(format: "%.2f", CMTimeGetSeconds(expectedTime)))/\(String(format: "%.2f", itemDuration))"
            }
        }
        
        if wasVideoPlaying {
            wasVideoPlaying = false
            self.playVideo()
        }
    }
    
    @objc fileprivate func didChange(Value slider: UISlider) {
        guard let _ = self.player, let itemPlaying = self.playerItem else {
            return
        }
        let itemDuration = CMTimeGetSeconds(itemPlaying.duration)
        let expectedTime = CMTimeMake(Int64(Float(itemDuration) * slider.value), Int32(1))
        
        self.videoTimerLabel.text = "\(String(format: "%.2f", CMTimeGetSeconds(expectedTime)))/\(String(format: "%.2f", itemDuration))"
    }
}

// MARK: UITouches
extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let metadataLayer = self.PlayerMetadataLayer else {
            return
        }
        var touchPoint = touch.location(in: self.view)
        touchPoint = self.view.layer.convert(touchPoint, to: metadataLayer as CALayer)
        if syncLayer.contains(touchPoint) {
            // the touch occoured on the syncLayer
            let expectedMetadata = self.playerItemDisplayedMetadata.filter({ (element) -> Bool in
                var valueToReturn = false
                if let displayedLayer = element["dataLayer"] as? CALayer, displayedLayer.contains(syncLayer.convert(touchPoint, to: displayedLayer)) == true, displayedLayer.opacity == 0.0 {
                    valueToReturn = true
                }
                return valueToReturn
            })
            for index in 0..<expectedMetadata.count {
                self.didSelectHotSpot(having: expectedMetadata[index])
            }
        }
    }
}
