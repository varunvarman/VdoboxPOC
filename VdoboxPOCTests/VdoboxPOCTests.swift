//
//  VdoboxPOCTests.swift
//  VdoboxPOCTests
//
//  Created by Varun on 17/05/17.
//  Copyright © 2017 Diet Code. All rights reserved.
//

import XCTest
import AVKit
import AVFoundation
@testable import VdoboxPOC

// Branch: POC_CAOverlayTests

class VdoboxPOCTests: XCTestCase {
    
    // MARK: Test Entities
    var viewController: ViewController?
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryViewController") as? ViewController
        viewController?.playerItemMetadata = [["videoID": "58f8a23214656a11005281ce" as AnyObject, "id": "58f8a5bf14656a11005281d0" as AnyObject, "startSecond": 105 as AnyObject, "createdAt": "2017-04-20T12:12:47.949Z" as AnyObject, "updatedAt": "2017-04-20T12:12:47.949Z" as AnyObject, "isDisplayed": 0 as AnyObject, "x": 6 as AnyObject, "endSecond": 105 as AnyObject, "tag": 0 as AnyObject, "y": 3 as AnyObject, "product": [:] as AnyObject]]
    }
    
    override func tearDown() {
        viewController = nil
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: Tests for Methods in ViewController
    
    // TEST: AVAsset is not nil
    func testAVAssetIsNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.asset)
    }
    
    // TEST: AVPlayerItem not nil
    func testAVPlayerItemNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.playerItem)
    }
    
    // TEST: AVPlayer Not Nil
    func testAVPlayerNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.player)
    }
    
    // TEST: variable 'periodicIntervalObserverToken' Not Nil
    func testPeriodicTimeIntervalObserverTokenNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.periodicIntervalObserverToken)
    }
    
    // TEST: AVPlayerlayer Not Nil
    func testAVPlayerLayerNotNil() {
        viewController?.initiatePlayer()
        XCTAssertNotNil(viewController?.playerLayer)
    }
    
    // TEST: Test if ViewController View is Not Nil
    func testViewControllerViewNotNil() {
        let _ = viewController?.view
        XCTAssertNotNil(viewController?.view)
    }
    
    // TEST: AVSynchoronousLayer Not Nil
    func testAVSynchronousLayerNotNil() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        XCTAssertNotNil(viewController?.synchronousLayer)
    }
    
    // TEST: Number of layers added equals the count of the metadata array
    func testNumberOfCALayersAddedEqualsPlayerMetadataCount() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        let subLayersCount = viewController?.synchronousLayer?.sublayers!.count
        XCTAssertNotNil(subLayersCount)
        XCTAssertNotEqual(subLayersCount, 0)
        XCTAssertEqual(subLayersCount, viewController?.playerItemMetadata.count, "The number of CALayers added as Sublayer NOT equal to the Count of objects in the playerItemMetadata array.")
    }
    
    // TEST: The Number of layers added equals the count of displayedData Array
    func testNumberOfCALayersEqualsTheDisplayedDataCount() {
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        let subLayersCount = viewController?.synchronousLayer?.sublayers!.count
        XCTAssertNotNil(subLayersCount)
        XCTAssertNotEqual(subLayersCount, 0)
        XCTAssertEqual(subLayersCount, viewController?.playerItemDisplayedMetadata.count, "The number of CAlayers added as sublayers NOT equal to the count of objects in the playerDisplayedItem Array.")
    }
    
    // TEST: AVSynchronousLayer added as sublayer
    func testAVSynchoronousLayerAddedAsSublayer() {
        var someSyncLayer: AVSynchronizedLayer?
        viewController?.initiatePlayer()
        viewController?.addPlayerMetadataLayer()
        for layer in (viewController?.view.layer.sublayers)! {
            if layer.isKind(of: AVSynchronizedLayer.classForCoder()) {
                someSyncLayer = layer as? AVSynchronizedLayer
            }
        }
        XCTAssertNotNil(someSyncLayer)
    }
}
