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
    @IBOutlet weak var videoTimeLabel: UILabel!
    @IBOutlet weak var videoSlider: UISlider! {
        didSet {
            self.videoSlider.addTarget(self, action: #selector(didStart(tracking:)), for: .touchDown)
            self.videoSlider.addTarget(self, action: #selector(didFinish(tracking:)), for: .touchUpInside)
            self.videoSlider.addTarget(self, action: #selector(didChange(value:)), for: .valueChanged)
            self.videoSlider.minimumTrackTintColor = UIColor(colorLiteralRed: 227.0/255.0, green: 76.0/255.0, blue: 65.0/255.0, alpha: 1.0)
            self.videoSlider.thumbTintColor = UIColor(colorLiteralRed: 227.0/255.0, green: 76.0/255.0, blue: 65.0/255.0, alpha: 1.0)
            self.videoSlider.maximumTrackTintColor = UIColor.gray
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
    fileprivate var synchronousLayer: AVSynchronizedLayer?
    fileprivate var boundryStartTimeObserverToken: Any?
    fileprivate var boundryEndTimeObserverToken: Any?
    fileprivate var periodicIntervalObserverToken: Any?
    fileprivate var playerItemMetadata: [[String: AnyObject]] = []
    fileprivate var playerItemDisplayedMetadata: [[String: AnyObject]] = []
    fileprivate var isVideoPlaying: Bool = false
    fileprivate var wasVideoPlaying: Bool = false
    fileprivate var isVideoReady: Bool = false {
        willSet {
            if newValue {
                self.videoSlider.alpha = 1.0
                self.videoSlider.isEnabled = true
                let totalDuration = CMTimeGetSeconds(self.player?.currentItem?.duration ?? CMTimeMake(Int64(0), Int32(0)))
                let currentDuration = CMTimeGetSeconds(self.player?.currentTime() ?? CMTimeMake(Int64(0), Int32(0)))
                self.videoTimeLabel.text = "\(String(format: "%.2f", currentDuration))/\(String(format: "%.2f", totalDuration))"
            } else {
                self.videoSlider.alpha = 0.7
                self.videoSlider.isEnabled = false
            }
        }
    }
    fileprivate let playerItemURL: URL = URL(string: "http://res.cloudinary.com/dtudhv7fy/video/upload/v1494568851/feradzbmxhnufb4xbsg1.mp4")!
    fileprivate let playerItemMetadataURL: URL = URL(string: "https://vdobox-api.herokuapp.com/api/v1/videoeditors?videoID=58f8a23214656a11005281ce")!
    
    // MARK: Life Cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupUI()
        fetchPlayerMetaData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let playR = self.player, let obsEndTime = self.boundryEndTimeObserverToken, let obsStartTime = self.boundryStartTimeObserverToken, let obsPeriodicInterval = self.periodicIntervalObserverToken else {
            return
        }
        playR.removeTimeObserver(obsEndTime)
        playR.removeTimeObserver(obsStartTime)
        playR.removeTimeObserver(obsPeriodicInterval)
    }
    
    // MARK: Utility Methods
    
    fileprivate func setupUI() {
        if isVideoReady {
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
                    print("\(Bundle.main.bundleIdentifier!)_JSON_DATA: \(jsonData)")
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
        })
        
        boundryEndTimeObserverToken = player?.addBoundaryTimeObserver(forTimes: endPoints, queue: nil, using: {
            [weak self] time in
            guard (self != nil), (self?.playerItemDisplayedMetadata.count)! > 0 else {
                return
            }
        })
        
        periodicIntervalObserverToken = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(Float64(1), Int32(1)), queue: nil, using: { (time) in
            // do something
            guard let videoPlayer = self.player else {
                return
            }
            let itemDuration = CMTimeGetSeconds((videoPlayer.currentItem?.duration)!)
            let currentTime = CMTimeGetSeconds(videoPlayer.currentTime())
            let sliderValue = Float(currentTime/itemDuration)
            self.videoSlider.setValue(sliderValue, animated: false)
            
            self.videoTimeLabel.text = "\(String(format: "%.2f", currentTime))/\(String(format: "%.2f", itemDuration))"
            
        })
    }
    
    fileprivate func addPlayerMetadataLayer() {
        // check if a Item to play is avaliable, also that its metadat array contsins elements, to overlay
        guard let playerItem = self.playerItem, self.playerItemMetadata.count > 0, let videoLayer = self.playerLayer, let currentPlayerItem = self.player?.currentItem else {
            return
        }
        for layer in self.view.layer.sublayers! {
            if layer.isKind(of: AVSynchronizedLayer.classForCoder()) {
                layer.removeFromSuperlayer()
            }
        }
        
        let videoDisplayRect = videoLayer.videoRect
        print("VIDEO FRAME: \(videoDisplayRect)")
        let videoGravity = currentPlayerItem.asset.tracks(withMediaType: AVMediaTypeVideo)[0]
        print("VIDEO Gravity: \(videoGravity)")
        print("VIDEO FRAME: \(videoLayer.frame)")
        
        let syncLayer = AVSynchronizedLayer(playerItem: playerItem)
        syncLayer.frame = CGRect(x: videoLayer.frame.origin.x, y: videoLayer.frame.origin.y, width: videoLayer.frame.width, height: videoLayer.frame.width)
        synchronousLayer = syncLayer
        
        for index in 0..<self.playerItemMetadata.count {
            
            var dataToDisplay = self.playerItemMetadata[index]
            let xCoordinate = ((CGFloat(dataToDisplay["x"] as? Int ?? 0) * videoDisplayRect.width) / videoGravity.naturalSize.width)
            let yCoordinate = ((CGFloat(dataToDisplay["y"] as? Int ?? 0) * videoDisplayRect.height) / videoGravity.naturalSize.height)
            let startTime = CFTimeInterval(dataToDisplay["startSecond"] as? Int ?? 0) // start Time
            let endTime = CFTimeInterval(dataToDisplay["endSecond"] as? Int ?? 0) //+ 5.0 // end Time
            
            let pinImage = UIImage(named: "pin")?.cgImage
            
            let touchLayer = CALayer()
            touchLayer.frame = CGRect(x: (videoDisplayRect.origin.x + xCoordinate), y: (videoDisplayRect.origin.y + yCoordinate), width: 30.0, height: 30.0)
            touchLayer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            touchLayer.backgroundColor = UIColor.clear.cgColor
            
            let dataLayer = CALayer()
            dataLayer.frame = CGRect(x: 0.0, y: 0.0, width: 30.0, height: 30.0)
            dataLayer.backgroundColor = UIColor.clear.cgColor
            dataLayer.contents = pinImage
            dataLayer.contentsGravity = kCAGravityResizeAspect
            dataLayer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            dataLayer.opacity = 0.0
            
            touchLayer.addSublayer(dataLayer)
            
            let showAnimation = CABasicAnimation(keyPath: "opacity")
            showAnimation.fromValue = NSNumber(value: 0.0)
            showAnimation.toValue = NSNumber(value: 1.0)
            showAnimation.duration = 0.5
            showAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            showAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + startTime //startTime
            showAnimation.fillMode = kCAFillModeBoth
            showAnimation.isRemovedOnCompletion = false
            dataLayer.add(showAnimation, forKey: "showOpacity")
            
            let hideAnimation = CABasicAnimation(keyPath: "opacity")
            hideAnimation.fromValue = NSNumber(value: 1.0)
            hideAnimation.toValue = NSNumber(value: 0.0)
            hideAnimation.duration = 0.5
            hideAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
            hideAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + endTime //endTime
            hideAnimation.fillMode = kCAFillModeForwards
            hideAnimation.isRemovedOnCompletion = false
            dataLayer.add(hideAnimation, forKey: "hideOpacity")
            
            syncLayer.addSublayer(touchLayer)
            
            dataToDisplay["isDisplayed"] = false as AnyObject
            dataToDisplay["dataLayer"] = dataLayer as AnyObject
            
            self.playerItemDisplayedMetadata.append(dataToDisplay)
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
        
        self.view.layer.addSublayer(syncLayer)
        
    }
    
    // MARK: AVPlayer Controller Methods
    func playVideo() {
        guard let player = self.player, isVideoReady == true else {
            return
        }
        if (!isVideoPlaying) {
            isVideoPlaying = true
            player.play()
        }
    }
    
    func pauseVideo() {
        guard let player = self.player, isVideoReady == true else {
            return
        }
        if (isVideoPlaying) {
            isVideoPlaying = false
            player.pause()
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
                self.isVideoReady = true
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
    
    // MARK: Slider Action Methods

    @objc fileprivate func didStart(tracking slider: UISlider) {
        guard let videoPlayer = self.player else {
            return
        }
        if videoPlayer.rate > 0 {
            wasVideoPlaying = true
            self.pauseVideo()
        }
    }
    
    @objc fileprivate func didFinish(tracking slider: UISlider) {
        guard let videoPlayer = self.player else {
            return
        }
        
        let itemDuration = CMTimeGetSeconds((videoPlayer.currentItem?.duration)!)
        let expectedTime = Float(itemDuration) * slider.value
        
        videoPlayer.seek(to: CMTimeMake(Int64(expectedTime), Int32(1)), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) { (status) in
            if status {
                // do something, after video seek success
            }
        }
        if wasVideoPlaying {
            wasVideoPlaying = false
            self.playVideo()
        }
    }
    
    @objc fileprivate func didChange(value slider: UISlider) {
        guard let videoPlayer = self.player else {
            return
        }
        
        let itemDuration = CMTimeGetSeconds((videoPlayer.currentItem?.duration)!)
        let expectedTime = Float(itemDuration) * slider.value
        
        self.videoTimeLabel.text = "\(String(format: "%.2f", expectedTime))/\(String(format: "%.2f", itemDuration))"
    }
}

// MARK: Touch Methods
extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let syncLayer = self.synchronousLayer else {
            return
        }
        var touchPoint = touch.location(in: self.view)
        touchPoint = self.view.layer.convert(touchPoint, to: syncLayer as CALayer)
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

