//
//  CustomARSceneFromCapturedRoom.swift
//  RoomPlanExampleApp
//
//  Created by user on 09.08.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import SceneKit
import RoomPlan
import UIKit

struct Point: Hashable {
    let x: Float
    let y: Float
}

enum FloorType {
    case full
    case cut
}

enum WallType {
    case full
    case cut
}

class CustomARSceneFromCapturedRoom: UIViewController, RoomCaptureSessionDelegate {
    var roomCaptureSession: RoomCaptureSession?
    var sceneView: SCNView!
    var finalRoom: CapturedRoom?
    var testFinalRoom: CapturedRoom?
    
    let floorType: FloorType = .full
    let wallType: WallType = .cut

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the SCNView
        sceneView = SCNView(frame: self.view.bounds)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        self.view.addSubview(sceneView)

        // Set up and start room capture
        setupRoomCaptureSession()
        startRoomCapture()
        if let fRoom = finalRoom {
            renderCapturedRoomInScene(fRoom)
        } else {
            guard let fRoom = getFRoom() else { return }
            renderCapturedRoomInScene(fRoom)
        }
    }

    func setupRoomCaptureSession() {
        roomCaptureSession = RoomCaptureSession()
        roomCaptureSession?.delegate = self
    }

    func startRoomCapture() {
        let configuration = RoomCaptureSession.Configuration()
        roomCaptureSession?.run(configuration: configuration)
    }

    func stopRoomCapture() {
        roomCaptureSession?.stop()
    }
    
    private func getFRoom() -> CapturedRoom? {
        let path = Bundle.main.path(forResource: "Room", ofType: "json") // file path for file "Room.json"
        guard let nonOptionalPath = path else { return nil }
        let roomJSONString = try? String(contentsOfFile: nonOptionalPath,
                                         encoding: String.Encoding.utf8)
        if let jsonString = roomJSONString {
            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()
            let fRoom = try? decoder.decode(CapturedRoom.self, from: data)
            return fRoom
        }
        return nil
    }
    
    func renderCapturedRoomInScene(_ capturedRoom: CapturedRoom) {
        // Create a new Scene
        let scene = SCNScene()
        
        // Add floor to the scene
        for floor in capturedRoom.floors {
            let floorNode: SCNNode
            switch floorType {
            case .full:
                floorNode = createFloorNode(from: floor)
            case .cut:
                let points = floor.polygonCorners.map { simd in
                    return Point(x: simd.x, y: simd.y)
                }
                floorNode = createClearFloorNode(from: floor, points: points)
                let pointMaxX = points.map({ point in return point.x}).max()
                let pointMinX = points.map({ point in return point.x}).min()
                let pointMaxY = points.map({ point in return point.y}).max()
                let pointMinY = points.map({ point in return point.y}).min()
                for point in points {
                    let pointGeometry = SCNSphere(radius: 0.3)
                    var color = UIColor.red
                    if point.x == pointMaxX {
                        color = UIColor.green
                    } else if point.x == pointMinX {
                        color = UIColor.blue
                    } else if point.y == pointMaxY {
                        color = UIColor.yellow
                    } else if point.y == pointMinY {
                        color = UIColor.cyan
                    }
                    pointGeometry.firstMaterial?.diffuse.contents = color

                    let pointNode = SCNNode(geometry: pointGeometry)
                    pointNode.position = SCNVector3(point.x, point.y, 0)
                    
                    floorNode.addChildNode(pointNode)
                }
            }
            scene.rootNode.addChildNode(floorNode)
        }

        switch wallType {
        case .full:
            // Add walls to the scene
            for wall in capturedRoom.walls {
                let wallNode = createWallNode(from: wall)
                scene.rootNode.addChildNode(wallNode)
            }
        case .cut:
            //add walls with subtrackted opennings(windows, doors, openings)
            for wall in capturedRoom.walls {
                let windows = capturedRoom.windows.filter({ $0.parentIdentifier == wall.identifier })
                let openings = capturedRoom.openings.filter({ $0.parentIdentifier == wall.identifier })
                let doors = capturedRoom.doors.filter({ $0.parentIdentifier == wall.identifier })
                let allOpenings = [windows, openings, doors].flatMap{$0}
                let wallNode = createWallWithOpeningNode(from: wall, allOpenings: allOpenings)
                scene.rootNode.addChildNode(wallNode)
            }
        }

        // Add doors to the scene
        for door in capturedRoom.doors {
            let doorNode = createDoorNode(from: door)
            scene.rootNode.addChildNode(doorNode)
        }

        // Add windows to the scene
        for window in capturedRoom.windows {
            let windowNode = createWindowNode(from: window)
            scene.rootNode.addChildNode(windowNode)
        }

        // Add objects to the scene
        for object in capturedRoom.objects {
            let objectNode = createObjectNode(from: object)
            scene.rootNode.addChildNode(objectNode)
        }

        // Set the scene to the SCNView
        sceneView.scene = scene
    }
    
    func createFloorNode(from floor: CapturedRoom.Surface) -> SCNNode {
        let length = CGFloat(floor.dimensions.x)
        let height = CGFloat(floor.dimensions.y)
        let thickness: CGFloat = 0.1

        let floorGeometry = SCNBox(width: length,
                                   height: height,
                                   length: thickness,
                                   chamferRadius: 0)
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.gray

        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.simdTransform = floor.transform

        return floorNode
    }
    
    func createClearFloorNode(from floor: CapturedRoom.Surface,
                              points: [Point]) -> SCNNode {
        var counter = 0
        let clearBezierPath = UIBezierPath()
        for point in points.reversed() {
            let cgPoint = CGPoint(x: CGFloat(point.x),
                                  y: CGFloat(point.y))
            if counter == 0 {
                clearBezierPath.move(to: cgPoint)
            } else if counter == (points.count - 1) {
                clearBezierPath.close()
            } else {
                clearBezierPath.addLine(to: cgPoint)
            }
            counter += 1
        }

        // Create an SCNShape with the defined path, extruded into 3D
        let shape = SCNShape(path: clearBezierPath,
                             extrusionDepth: 0.1)
        shape.firstMaterial?.diffuse.contents = UIColor.gray

        // Create an SCNNode with the shape
        let shapeNode = SCNNode(geometry: shape)
        shapeNode.simdTransform = floor.transform

        // Add the hollow box to the scene
        return shapeNode
    }

    func createWallNode(from wall: CapturedRoom.Surface) -> SCNNode {
        let length = CGFloat(wall.dimensions.x)
        let height = CGFloat(wall.dimensions.y)
        let thickness: CGFloat = 0.1

        let wallGeometry = SCNBox(width: length,
                                  height: height,
                                  length: thickness,
                                  chamferRadius: 0)
        wallGeometry.firstMaterial?.diffuse.contents = UIColor.gray

        let wallNode = SCNNode(geometry: wallGeometry)
        wallNode.simdTransform = wall.transform
        
        return wallNode
    }

    func createDoorNode(from door: CapturedRoom.Surface) -> SCNNode {
        let width = CGFloat(door.dimensions.x)
        let height = CGFloat(door.dimensions.y)
        let thickness: CGFloat = 0.05

        let doorGeometry = SCNBox(width: width,
                                  height: height,
                                  length: thickness,
                                  chamferRadius: 0)
        doorGeometry.firstMaterial?.diffuse.contents = UIColor.brown

        let doorNode = SCNNode(geometry: doorGeometry)
        doorNode.simdTransform = door.transform

        return doorNode
    }

    func createWindowNode(from window: CapturedRoom.Surface) -> SCNNode {
        let width = CGFloat(window.dimensions.x)
        let height = CGFloat(window.dimensions.y)
        let thickness: CGFloat = 0.05

        let windowGeometry = SCNBox(width: width,
                                    height: height,
                                    length: thickness,
                                    chamferRadius: 0)
        windowGeometry.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.3)

        let windowNode = SCNNode(geometry: windowGeometry)
        windowNode.simdTransform = window.transform

        return windowNode
    }

    func createObjectNode(from object: CapturedRoom.Object) -> SCNNode {
        let size = object.dimensions
        
        let objectGeometry = SCNBox(width: CGFloat(size.x),
                                    height: CGFloat(size.y),
                                    length: CGFloat(size.z),
                                    chamferRadius: 0)
        objectGeometry.firstMaterial?.diffuse.contents = UIColor.lightGray
        
        let objectNode = SCNNode(geometry: objectGeometry)
        objectNode.simdTransform = object.transform
        
        return objectNode
    }
    
    func createWallWithOpeningNode(from wall: CapturedRoom.Surface,
                                   allOpenings: [CapturedRoom.Surface]) -> SCNNode {
        let wallRect = CGRect(x: CGFloat(-wall.dimensions.x / 2),
                              y: CGFloat(-wall.dimensions.y / 2),
                              width: CGFloat(wall.dimensions.x),
                              height: CGFloat(wall.dimensions.y))
        let wallBezierPath = UIBezierPath(rect: wallRect)
        for openning in allOpenings {
            let openningX = CGFloat(-openning.dimensions.x / 2) - CGFloat(wall.transform.columns.3.x - openning.transform.columns.3.x)
            let openningY = CGFloat(-openning.dimensions.y / 2) - CGFloat(wall.transform.columns.3.y - openning.transform.columns.3.y)
            let openningRect = CGRect(x: openningX,
                                      y: openningY,
                                      width: CGFloat(openning.dimensions.x),
                                      height: CGFloat(openning.dimensions.y))
            let openningBezierPath = UIBezierPath(rect: openningRect)
            wallBezierPath.cgPath = wallBezierPath.cgPath.subtracting(openningBezierPath.cgPath)
            print(wall)
            print(openning)
        }

        // Create an SCNShape with the defined path, extruded into 3D
        let shape = SCNShape(path: wallBezierPath, extrusionDepth: 0.1)
        shape.firstMaterial?.diffuse.contents = UIColor.darkGray

        // Create an SCNNode with the shape
        let shapeNode = SCNNode(geometry: shape)
        shapeNode.simdTransform = wall.transform

        // Add the hollow box to the scene
        return shapeNode
    }
}
