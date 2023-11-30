//
//  ViewController.swift
//  artest
//
//  Created by Juwon Hyun on 2023/11/14.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var arButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    //Text
    @IBOutlet weak var textLowest: UITextField!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textHeight: UITextField!
    @IBOutlet weak var textObject: UITextField!
    
    // 전역변수
    struct wall {
        var anchor: ARAnchor
    }
    var wallA: wall?
    var wallB: wall?
    var isNext:Bool = true
    //노드를 삭제를 위한 createnodes
    var createdNodes = [SCNNode]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
            DispatchQueue.main.async {
                for node in self.createdNodes {
                    node.removeFromParentNode()
                }
                self.createdNodes.removeAll()
            }
        }
        
        sceneView.delegate = self
        //sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        sceneView.showsStatistics = true
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        configuration.frameSemantics.insert(.sceneDepth)
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: setting renderers
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        //guard let cameraPointOfView = sceneView.pointOfView?.rotation else{ return }

        //setting for pointCloud maxdistance
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else { return }
        //get initial camera position
        let cameraPosition = simd_make_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        //set MaxDistance for pointCloud
        guard let pointCloudBefore = sceneView.session.currentFrame?.rawFeaturePoints else { return }
        let maxDistance: Float = 5.0
        let pointCloud = pointCloudBefore.points.filter { point in
            let distance = simd_distance(cameraPosition, point)
            return distance <= maxDistance
        }
        
        
        //let points = pointCloud
        //var lowestDot : Float = Float.infinity
        
        // create parentnode
        let parent = SCNNode()
        
        //try with point.count
        /*
        //get lowest Heights
        for point in points{
            if point.y <= lowestDot{
                lowestDot = point.y
            }
        }
        */
        
        // Regruoup height
        let heights = pointCloud.map{$0.y}

        //set moving average
        //return height if height > avg otherwise nil
        //nil will delete by compactMap()
        //obstaclePoint will have just (height > avg) point array
        let ave = movingAverage(size: 32768)
        let obstaclePoints = heights.map{ height in
            let avg = ave.add(height)
            return height > avg ? height: nil
        }.compactMap{$0}
        
        //Percentile
        
        
        //let obstaclePoints = heights.filter{ $0 > (lowestDot+0.1)}
        let obstacleLimit: Int = 100
        if obstaclePoints.count > obstacleLimit{
            DispatchQueue.main.async {
                self.textHeight.text = "Obstacle points =\(obstaclePoints.count)"
                self.textObject.text = "Obstacles found"
            }
        }else{
            DispatchQueue.main.async{
                self.textHeight.text = "Obstacle points =\(obstaclePoints.count)"
                self.textObject.text = "OK!            "
            }
        }
        

        
        /*
        //place the parentnode by stride()
        for i in stride(from: 0, to: points.count, by: 50){
            let point = points[i]
            let node = SCNNode()
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.yellow
            node.geometry = SCNSphere(radius: 0.007)
            node.geometry?.firstMaterial = material
            node.position = SCNVector3(point.x, point.y, point.z)
            parent.addChildNode(node)
        }
        */
        
        DispatchQueue.main.async {
            self.sceneView.scene.rootNode.addChildNode(parent)
            self.createdNodes.append(parent)
            self.textLowest.text = "obstacle limit = \(obstacleLimit)"
            //self.textHeight.text = "ave_height = \(aveY)"
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let parent = SCNNode()
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            node.addChildNode(createWallNode(planeAnchor: planeAnchor))
            DispatchQueue.main.async{
                self.textView.text = "Find \(planeAnchor.classification)\n name = \(planeAnchor.identifier)\n  eulerAngles = \(node.eulerAngles)\n\n rotation = \(node.rotation)"
            }
        }
        
        //create line node
        if wallA?.anchor != nil && wallB?.anchor != nil{
            let nodeLine1 = SCNNode()
            let nodeLine2 = SCNNode()
            var lengthNode = SCNNode()
            
            if let transform1 = wallA?.anchor.transform, let transform2 = wallB?.anchor.transform{
                nodeLine1.simdTransform = transform1
                nodeLine2.simdTransform = transform2
                
                let lineGeometry = SCNGeometry.line(from: nodeLine1.position, to: nodeLine2.position)
                let lineNode = SCNNode(geometry: lineGeometry)
                //sceneView.scene.rootNode.addChildNode(lineNode)
                
                //create Text node
                let length = distance(transform1: transform1, transform2: transform2)
                let lengthText = "\(String(format: "%.2f", length))m"
                let textGeometry = SCNText(string: lengthText, extrusionDepth: 0.01)
                textGeometry.font = UIFont.systemFont(ofSize: 0.2)
                textGeometry.flatness = 1
                lengthNode = SCNNode(geometry: textGeometry)
                lengthNode.position = SCNVector3((nodeLine1.position.x+nodeLine2.position.x)/2, -0.9, (nodeLine1.position.z + nodeLine2.position.z)/2)
                let billboardConstraint = SCNBillboardConstraint()
                lengthNode.constraints = [billboardConstraint]
                //sceneView.scene.rootNode.addChildNode(lengthNode)
            
                
                parent.addChildNode(lineNode)
                parent.addChildNode(lengthNode)
                DispatchQueue.main.async{
                    self.sceneView.scene.rootNode.addChildNode(parent)
                    self.createdNodes.append(parent)
                    
                }
            }
        }
    }
    
    
    func session(_ session: ARSession ,didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    
    // MARK: Useful(created) functions
    
    func createSpearNode(anchor: ARAnchor) -> SCNNode{
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.yellow
        node.geometry = SCNSphere(radius: 0.007)
        node.geometry?.firstMaterial = material
        node.position = SCNVector3(point.x, point.y, point.z)
        parent.addChildNode(node)
        
        return spear
    }
    
    func createWallNode(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let width = CGFloat(planeAnchor.planeExtent.width)
        let height = CGFloat(planeAnchor.planeExtent.height)
        let center = planeAnchor.center
        let plane = SCNPlane(width: width, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.geometry?.materials = [material]
        planeNode.eulerAngles.x = -.pi / 2 // set the angle to attach to the wall
        planeNode.position = SCNVector3(center.x, 0, center.z)
        
        
        addWall(anchor: planeAnchor)
        
        DispatchQueue.main.async {
            self.textView.text = "Find \(planeAnchor.classification)\n\n width = \(width)\n height = \(height)\n\n rotation = \(planeNode.rotation)"
        }
        //print("Find \(planeAnchor.classification)\n\n width = \(width)\n height = \(height)\n\n rotation = \(planeNode.rotation)")
        return planeNode
        }
    
    
    //return ARAnchor.0, ARAnchor.1
    func findClosestAnchors() -> (ARAnchor, ARAnchor)? {
        guard let anchors = sceneView.session.currentFrame?.anchors else{return nil}
        var minDistance = Float.greatestFiniteMagnitude
        var closePair: (ARAnchor,ARAnchor)?
        
        for i in 0..<anchors.count{
            for j in i+1..<anchors.count{
                let distance = distanceBetweenAnchors(anchor1: anchors[i], anchor2: anchors[j])
                if distance < minDistance {
                    minDistance = distance
                    closePair = (anchors[i], anchors[j])
                }
            }
        }
        return closePair
    }
    
    func addWall (anchor : ARAnchor){

        if isNext{
            wallA = wall(anchor: anchor)
        }else{
            wallB = wall(anchor: anchor)
        }
        isNext = !isNext
    }
    
    func findClosestAnchorsFromCamera() -> ARAnchor? {
        guard let anchors = sceneView.session.currentFrame?.anchors,
              let cameraTransform = sceneView.session.currentFrame?.camera.transform else {return nil}
        
        var minDistance = Float.greatestFiniteMagnitude
        var closestWallAnchor : ARAnchor?
        
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                let distance = distance(transform1: cameraTransform, transform2: anchor.transform)
                if distance < minDistance {
                    minDistance = distance
                    closestWallAnchor = anchor
                }
            }
        }
        return closestWallAnchor
    }
    
    
    func distance(transform1:matrix_float4x4, transform2:matrix_float4x4) -> Float{
        let dx = transform1.columns.3.x - transform2.columns.3.x
        let dy = transform1.columns.3.y - transform2.columns.3.y
        let dz = transform1.columns.3.z - transform2.columns.3.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    func distanceBetweenAnchors(anchor1: ARAnchor, anchor2: ARAnchor) -> Float {
        let position1 = anchor1.transform.columns.3
        let position2 = anchor2.transform.columns.3
        return simd_distance(position1, position2)
    }

}


// MARK: Classes

class movingAverage{
    private var size: Int
    private var history: [Float] = []
    
    init(size:Int){
        self.size = size
    }
    func add(_ value: Float) -> Float{
        history.append(value)
        if history.count > size{
            history.removeFirst()
        }
        return average()
    }
    
    func average() -> Float{
        return history.reduce(0, +) / Float(history.count)
    }
}


// MARK: extensions

extension SCNGeometry {
    class func line(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
        let indices: [UInt32] = [0, 1]
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)

        return SCNGeometry(sources: [source], elements: [element])
    }
}



extension Array where Element: Numeric & Comparable {
    func percentile(_ percentile: Double) -> Element? {
        let sorted = self.sorted()
        let index = Int(Double(count) * percentile / 100.0)
        return index < count ? sorted[index] : nil
    }
}
