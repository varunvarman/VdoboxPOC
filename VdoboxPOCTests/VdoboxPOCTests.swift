//
//  VdoboxPOCTests.swift
//  VdoboxPOCTests
//
//  Created by Varun on 18/05/17.
//  Copyright © 2017 Diet Code. All rights reserved.
//

import XCTest
import AVKit
import AVFoundation
@testable import VdoboxPOC

class VdoboxPOCTests: XCTestCase {
    
    // MARK: Common Properties
    var viewController: ViewController?
    
    override func setUp() {
        super.setUp()
        viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryViewController") as? ViewController
        viewController?.playerItemMetadata = [["videoID": "58f8a23214656a11005281ce" as AnyObject, "id": "58f8a5bf14656a11005281d0" as AnyObject, "startSecond": 100 as AnyObject, "createdAt": "2017-04-20T12:12:47.949Z" as AnyObject, "updatedAt": "2017-04-20T12:12:47.949Z" as AnyObject, "isDisplayed": 0 as AnyObject, "x": 6 as AnyObject, "endSecond": 110 as AnyObject, "tag": 0 as AnyObject, "y": 3 as AnyObject, "product": [:] as AnyObject]]
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        viewController = nil
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Tests -:- initiatePlayer()
    
    // Test: AVAsset Not Nil
    func testAVAssetNoNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.asset)
    }
    
    // Test: AVPlayer Not Nil
    func testAVPlayerItemNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.playerItem)
    }
    
    // Test: AVPlayer not Nil
    func testAVPlayerNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.player)
    }
    
    // Test: AVPlayerLayer Not Nil
    func testAVPlayerLayerNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.playerLayer)
    }
    
    // Test: variable 'boundryStartTimeObserverToken' not nil
    func testBoundryStartTimeObserverNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.boundryStartTimeObserverToken)
    }
    
    // Test: variable 'boundryEndTimeObserverToken' not nil
    func testBoundryEndTimeObserverNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.boundryEndTimeObserverToken)
    }
    
    // Test: variable 'periodicIntervalObserverToken' Not Nil
    func testPeriodicIntervalObserverTokenNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.periodicIntervalTimeObserver)
    }
    
    // Test: AVPlayerLayer added as Sublayer to view.Layer
    func testAVPlayerlayerAddedAsSubLayer() {
        var playerLayer: AVPlayerLayer?
        viewController?.initiatePlayer()
        let someView = viewController?.view
        let someViewLayer = someView?.layer
        for layer in (someViewLayer?.sublayers)! {
            if layer.isKind(of: AVPlayerLayer.classForCoder()) {
                playerLayer = layer as? AVPlayerLayer
            }
        }
        XCTAssertNotNil(playerLayer)
    }
    
    // MARK: Test -:- addPlayerMetadatalayer()
    
    // Test: variable 'playerMetadataLayer' Not Nil
    func testPlayerMetadatalayerNotNil() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        XCTAssertNotNil(viewController?.playerMetadataLayer)
    }
    
    // Test: No. of layers added equals the PlayerItemMetadata Array Count
    func testNumberOfLayersAddedEqualsTheCounOfPlayerItemMetadataCount() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        XCTAssertNotNil(viewController?.playerMetadataLayer)
        XCTAssertEqual(viewController?.playerMetadataLayer?.sublayers?.count, viewController?.playerItemMetadata.count)
    }
    
    // Test: variable 'playerMetadataLayer' ass as sublayer to view.layer
    func testPlayerMetadatalayerIsSublayer() {
        var possiblePlayerLayer: CALayer?
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        let someViewLayer = viewController?.view.layer
        for layer in (someViewLayer?.sublayers)! {
            if layer == viewController?.playerMetadataLayer {
                possiblePlayerLayer = layer
            }
        }
        XCTAssertNotNil(possiblePlayerLayer)
    }
    
    // Test: Number of items in the variable 'playerItemDisplayedMetadata' equals the Predicate where startSecond <= currentTime & endSecond >= currentTime
    func testCountPlayerItemDisplayedMetadataEqualsSetPredicate() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        viewController?.videoDidScrub(to: 101.0)
        let currentTime = 101 // assumed time space, current value
        let displayedData = viewController?.playerItemMetadata.filter({ (element) -> Bool in
            var valueToSelect: Bool = false
            if let startSecond = element["startSecond"] as? Int, startSecond <= currentTime, let endSecond = element["endSecond"] as? Int, endSecond >= currentTime, let displayedLayer = element["dataLayer"] as? CALayer, displayedLayer.opacity == 0.0 {
                valueToSelect = true
            }
            return valueToSelect
        })
        XCTAssertEqual(viewController?.playerItemDisplayedMetadata.count, displayedData?.count)
    }
    
    // Test: Number of elements in variable 'playerItemDisplayedMetadata' equals the result of the predicate where stardSecond <= currentTime && endSecond > currentTime when using ''displayData()'
    func testCountPlayerItemDisplayedMetadataEqualsCountUsingSetPredicateOnDisplaydataMethodCall() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        viewController?.displayData()
        let currentTime = 0 // assumed time space, current value
        let displayedData = viewController?.playerItemMetadata.filter({ (element) -> Bool in
            var valueToReturn: Bool = false
            if let startSecond = element["startSecond"] as? Int, startSecond <= currentTime, let endSecond = element["endSecond"] as? Int, endSecond > currentTime, let displayedLayer = element["dataLayer"] as? CALayer, displayedLayer.opacity == 0.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        XCTAssertEqual(displayedData?.count, viewController?.playerItemDisplayedMetadata.count)
    }
    
    // Test: Number of elements in 'playerItemDisplayedMetadata' equals the result of the predicate where startSecond < currentTime && endSecond > currentTime when using 'hideData()'
    func testCountPlayerItemDisplayedMetadataEqualsCountUsingSetPredicateOnhideDataMethodCall() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        viewController?.hideData()
        let currentTime = 0 // assumed time Space, current value
        let displayedData = viewController?.playerItemMetadata.filter({ (element) -> Bool in
            var valueToReturn: Bool = false
            if let startSecond = element["startSecond"] as? Int, startSecond <= currentTime, let endSecond = element["endSecond"] as? Int, endSecond > currentTime, let displayedLayer = element["dataLayer"] as? CALayer, displayedLayer.opacity == 0.0 {
                valueToReturn = true
            }
            return valueToReturn
        })
        XCTAssertEqual(displayedData?.count, viewController?.playerItemDisplayedMetadata.count)
    }
}
