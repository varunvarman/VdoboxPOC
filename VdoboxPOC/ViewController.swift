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
    fileprivate var boundryStartTimeObserverToken: Any?
    fileprivate var boundryEndTimeObserverToken: Any?
    fileprivate var playerItemMetadata: [[String: AnyObject]] = []
    fileprivate var playerItemDisplayedMetadata: [[String: AnyObject]] = []
    fileprivate var isVideoPlaying: Bool = false
    fileprivate let playerItemURL: URL = URL(string: "https://res.cloudinary.com/vdobox/video/upload/v1491284125/hyxqi2yoedoh9ti4dvd8.mp4")!
    fileprivate let playerItemMetadataURL: URL = URL(string: "https://vdobox-api.herokuapp.com/api/v1/videoeditors?videoID=58f8a23214656a11005281ce")!
    
    // MARK: Life Cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
        guard let playR = self.player, let obs = self.boundryEndTimeObserverToken else {
            return
        }
        playR.removeTimeObserver(obs)
    }
    
    // MARK: Utility Methods
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
            return NSValue(time: CMTimeMake(Int64(30), Int32(1)))
        }
        let startPoints = self.playerItemMetadata.map { (object) -> NSValue in
            let startTime = object["startSecond"] as? Int ?? 0
            return NSValue(time: CMTimeMake(Int64(10), Int32(1)))
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
            //print("\(Bundle.main.bundleIdentifier!)_TIME_OBSERVED: \(Float(CMTimeGetSeconds((self?.player?.currentTime())!)))")
            guard (self != nil), (self?.playerItemDisplayedMetadata.count)! > 0 else {
                return
            }
            self?.hideData()
            self?.player?.seek(to: CMTimeMake(Int64(8), Int32(1)))
        })
    }
    
    fileprivate func addPlayerMetadataLayer() {
        // check if a Item to play is avaliable, also that its metadat array contsins elements, to overlay
        guard let playerItem = self.playerItem, self.playerItemMetadata.count > 0 else {
            return
        }
        for layer in self.view.layer.sublayers! {
            if layer.isKind(of: AVSynchronizedLayer.classForCoder()) {
                layer.removeFromSuperlayer()
            }
        }
        
       // let syncLayer = AVSynchronizedLayer(playerItem: playerItem)
        
        let standardlayer = CALayer()
        standardlayer.frame = CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.width, height: self.view.frame.size.width)
        standardlayer.backgroundColor = UIColor.clear.cgColor
        
        for index in 0..<self.playerItemMetadata.count {
            
            var dataToDisplay = self.playerItemMetadata[index]
            let xCoordinate = CGFloat(dataToDisplay["x"] as? Int ?? 0)
            let yCoordinate = CGFloat(dataToDisplay["y"] as? Int ?? 0)
            let startTime = CFTimeInterval(dataToDisplay["startSecond"] as? Int ?? 0) // start Time
            let _ = CFTimeInterval(dataToDisplay["endSecond"] as? Int ?? 0) + 10.0 // end Time
            
            let pinImage = UIImage(named: "pin")?.cgImage
            
            let dataLayer = CALayer()
            dataLayer.frame = CGRect(x: (0.0 + xCoordinate), y: (84.0 + yCoordinate), width: 30.0, height: 30.0)
            dataLayer.backgroundColor = UIColor.clear.cgColor
            dataLayer.contents = pinImage
            dataLayer.contentsGravity = kCAGravityResizeAspect
            dataLayer.contentsRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            dataLayer.opacity = 0.0
            //self.view.layer.addSublayer(dataLayer)
            
//            let keyFrameAnimation = CAKeyframeAnimation(keyPath: "opacity")
//            keyFrameAnimation.values = [0.0, 0.25, 0.50, 0.75, 1.0]
//            keyFrameAnimation.keyTimes = [0.0, 0.25, 0.50, 0.75, 1.0]
//            keyFrameAnimation.duration = 0.5//((endTime - startTime) > 0 ? ((endTime - startTime)) : 1.0)
//            keyFrameAnimation.timingFunctions = [CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)]
//            keyFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
//            keyFrameAnimation.fillMode = kCAFillModeBackwards
//            keyFrameAnimation.isRemovedOnCompletion = false
            
//            let showAnimation = CABasicAnimation(keyPath: "opacity")
//            showAnimation.fromValue = NSNumber(value: 0.0)
//            showAnimation.toValue = NSNumber(value: 1.0)
//            showAnimation.duration = 0.5
//            showAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
//            showAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + 10.0
//            showAnimation.fillMode = kCAFillModeBackwards
//            showAnimation.isRemovedOnCompletion = false
//            showAnimation.delegate = self
//            dataLayer.add(showAnimation, forKey: "showOpacity")
//            
//            let hideAnimation = CABasicAnimation(keyPath: "opacity")
//            hideAnimation.fromValue = NSNumber(value: 1.0)
//            hideAnimation.toValue = NSNumber(value: 0.0)
//            hideAnimation.duration = 0.5
//            hideAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
//            hideAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + 20.0
//            showAnimation.fillMode = kCAFillModeForwards
//            hideAnimation.isRemovedOnCompletion = false
//            hideAnimation.delegate = self
//            dataLayer.add(hideAnimation, forKey: "hideOpacity")
            
           // syncLayer.addSublayer(dataLayer)
            standardlayer.addSublayer(dataLayer)
            
            dataToDisplay["isDisplayed"] = false as AnyObject
            dataToDisplay["dataLayer"] = dataLayer as AnyObject
            
            self.playerItemMetadata.insert(dataToDisplay, at: index)
            
//            self.playerItemDisplayedMetadata.append(dataToDisplay)
//            self.playerItemDisplayedMetadata.sort(by: { (element0, element1) -> Bool in
//                guard let startTime0 = element0["endSecond"] as? Int else {
//                    return false
//                }
//                guard let startTime1 = element1["endSecond"] as? Int else {
//                    return false
//                }
//                return startTime0 < startTime1
//            })
        }
        
        self.view.layer.addSublayer(standardlayer)
        //self.view.layer.insertSublayer(dataLayer, above: videoLayer)
        
    }
    
    fileprivate func videoDidScrub(to playTime: Float) {
        let currentTime = playTime //Float(CMTimeGetSeconds((self.player?.currentTime())!))
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
                let dataLayer = object["datalayer"] as? CALayer
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
        
        let currentTime = Float(CMTimeGetSeconds((self.player?.currentTime())!))
        
        let elementsToDisplayOptional = self.playerItemMetadata.filter({ (element) -> Bool in
            var valueToReturn = false
            if let startSecond = element["startSecond"] as? Int, startSecond == 105, let layerToDisplay = element["dataLayer"] as? CALayer, layerToDisplay.opacity == 0.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        
        if let elementsToDisplay = elementsToDisplayOptional as? [[String: AnyObject]] {
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
    }
    
    fileprivate func hideData() {
        let currentTime = Float(CMTimeGetSeconds((self.player?.currentTime())!))
        
        let elementsToHideOptional = self.playerItemDisplayedMetadata.filter({ (element) -> Bool in
            var valueToReturn = false
            if let endSecond = element["endSecond"] as? Int, endSecond == 105, let dataLayer = element["dataLayer"] as? CALayer, dataLayer.opacity == 1.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        if let elementsToHide = elementsToHideOptional as? [[String: AnyObject]] {
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
    }
    
    // MARK: AVPlayer Controller Methods
    func playVideo() {
        guard let player = self.player else {
            return
        }
        if (!isVideoPlaying) {
            isVideoPlaying = true
            player.play()
        }
    }
    
    func pauseVideo() {
        guard let player = self.player else {
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


}

//extension ViewController: CAAnimationDelegate {
//    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        if (flag) {
//            
//        }
//    }
//}

