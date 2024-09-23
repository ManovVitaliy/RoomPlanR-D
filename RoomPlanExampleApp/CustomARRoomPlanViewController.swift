//
//  CustomARRoomPlan.swift
//  RoomPlanExampleApp
//
//  Created by user on 18.07.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import SceneKit
import RoomPlan

final class CustomARRoomPlanViewController: UIViewController {
    private var sceneView: SCNView?
    private var scene: SCNScene?
    var finalRoom: CapturedRoom?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        createRoom()
    }
    
    private func setupScene() {
        sceneView = SCNView(frame: self.view.bounds)
        sceneView?.backgroundColor = .red
        if let scnView = sceneView {
            view.addSubview(scnView)
        }
        scene = SCNScene()
        sceneView?.scene = scene
        
        sceneView?.allowsCameraControl = true
        sceneView?.defaultCameraController.interactionMode = .orbitTurntable
        sceneView?.defaultCameraController.inertiaEnabled = true
        sceneView?.defaultCameraController.maximumVerticalAngle = 89
        sceneView?.defaultCameraController.minimumVerticalAngle = -89
    }
    
    func createRoom() {
        guard let roomResult = finalRoom else { return }
        let objects = [roomResult.floors, roomResult.walls, roomResult.windows, roomResult.doors]
        for object in objects {
            for scannedWall in object {
             
                //Generate new wall geometry
                let length = 0.2
                let width = scannedWall.dimensions.x
                let height = scannedWall.dimensions.y
                let newWall = SCNBox(
                   width: CGFloat(width),
                   height: CGFloat(height),
                   length: CGFloat(length),
                   chamferRadius: 0
                )
                        
                newWall.firstMaterial?.diffuse.contents = UIColor.white
                newWall.firstMaterial?.transparency = 0.8
                        
                //Generate new SCNNode
                let newNode = SCNNode(geometry: newWall)
                newNode.simdTransform = scannedWall.transform

                scene?.rootNode.addChildNode(newNode)
            }
        }
    }
}
