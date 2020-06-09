//
//  ViewController.swift
//  MeshDemo
//
//  Created by Nikita Evstigneev on 13/05/2020.
//  Copyright © 2020 SABO Mobile IT. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    private let colorizer = Colorizer()
    
    private let lavaMaterial: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIImage(named: "art.scnassets/lava.jpg")
        return m
    }()
    
    private var lastUpdatedAt: TimeInterval = 0
    private var isProcessing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        sceneView.prepare(lavaMaterial, shouldAbortBlock: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification

        // Run the view's session
        sceneView.session.delegate = self
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let meshAnchor = anchor as? ARMeshAnchor else {
            return nil
        }
        
        // Main node
        let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)
        geometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
        let node = SCNNode(geometry: geometry)
        node.name = "DynamicNode-\(meshAnchor.identifier)"
        
        // Floor node
//        if let floorGeometry = SCNGeometry.from(meshAnchor.geometry, ofType: .floor) {
//            floorGeometry.replaceMaterial(at: 0, with: lavaMaterial)
//            let floorNode = SCNNode(geometry: floorGeometry)
//            floorNode.name = "Floor"
//            node.addChildNode(floorNode)
//        }
        
        // Normals node
        let normalsForest = SCNGeometry.normalForest(from: meshAnchor.geometry)
        normalsForest.firstMaterial?.diffuse.contents = UIColor.red
        let normalsNode = SCNNode(geometry: normalsForest)
        normalsNode.name = "Normals"
        node.addChildNode(normalsNode)
        
        return node
    }
    
//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        // Update at max 1 time per second
//        if (time - lastUpdatedAt > 0.5 && !isProcessing) {
//            isProcessing = true
//            DispatchQueue.global().async {
//                let meshAnchors = (self.sceneView.session.currentFrame?.anchors.filter { $0 is ARMeshAnchor } ?? []) as! [ARMeshAnchor]
//                for anchor in meshAnchors {
//                    // Main node
//                    let node = self.sceneView.node(for: anchor)
//                    //        let newGeometry = SCNGeometry(arGeometry: anchor.geometry)  // regenerate geometry
//                    //        newGeometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
//                    //        node.geometry = newGeometry
//
//                    // Floor node
//                    let existingFloorNode = node?.childNode(withName: "Floor", recursively: false)
//                    if let floorGeometry = SCNGeometry.from(anchor.geometry, ofType: .floor) {
//                        floorGeometry.replaceMaterial(at: 0, with: self.lavaMaterial)
//                        if let floorNode = existingFloorNode {
//                            floorNode.geometry = floorGeometry
//                        } else {
//                            let floorNode = SCNNode(geometry: floorGeometry)
//                            floorNode.name = "Floor"
//                            node?.addChildNode(floorNode)
//                        }
//                    } else {
//                        existingFloorNode?.removeFromParentNode()
//                    }
//                }
//                self.isProcessing = false
//                self.lastUpdatedAt = time
//            }
//        }
//    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor else { return }
        // Main node
        let newGeometry = SCNGeometry(arGeometry: meshAnchor.geometry)  // regenerate geometry
        newGeometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
        node.geometry = newGeometry
        
        // Floor node
//        let existingFloorNode = node.childNode(withName: "Floor", recursively: false)
//        if let floorGeometry = SCNGeometry.from(meshAnchor.geometry, ofType: .floor) {
//            floorGeometry.replaceMaterial(at: 0, with: self.lavaMaterial)
//            if let floorNode = existingFloorNode {
//                floorNode.geometry = floorGeometry
//            } else {
//                let floorNode = SCNNode(geometry: floorGeometry)
//                floorNode.name = "Floor"
//                node.addChildNode(floorNode)
//            }
//        } else {
//            existingFloorNode?.removeFromParentNode()
//        }
        
        // Normals node
        if let normalsNode = node.childNode(withName: "Normals", recursively: false) {
            let normalsForest = SCNGeometry.normalForest(from: meshAnchor.geometry)
            normalsForest.firstMaterial?.diffuse.contents = UIColor.red
            normalsNode.geometry = normalsForest
        }
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let meshAnchors = frame.anchors.filter { $0 is ARMeshAnchor } as! [ARMeshAnchor]
        
        print("I currently see \(meshAnchors.count) mesh anchors")
    }
}
