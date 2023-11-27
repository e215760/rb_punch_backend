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
    
    //노드를 삭제하기 위해서 createnodes를 작성
    var createdNodes = [SCNNode]()
    var isARRunning = false
    
    // 전역변수
    struct wall {
        var anchor: ARAnchor
    }
    var wallA: wall?
    var wallB: wall?
    var isNext:Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //delete all nodes in withTimeInterval
        //withTimeInterval -> seconds
        Timer.scheduledTimer(withTimeInterval: 1330.0, repeats: true) { timer in
            DispatchQueue.main.async {
                for node in self.createdNodes {
                    node.removeFromParentNode()
                }
                self.createdNodes.removeAll()
            }
        }
        
        sceneView.delegate = self
        //sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        //sceneView.showsStatistics = true
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
    
    
    //renderer update by TimeInterval -> it will update all Frames(60FPS)
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        // create pointCloud
        guard let pointCloud = sceneView.session.currentFrame?.rawFeaturePoints else { return }
        
        // create parentnode
        let parent = SCNNode()
        
        /*
        // create smoothedDepthMap
        guard let frame = sceneView.session.currentFrame,
              let depthData = frame.smoothedSceneDepth else{ return }
        
        let depthImage = depthData.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthImage)
        let depthHeight = CVPixelBufferGetHeight(depthImage)
        
        // 깊이 이미지에서 픽셀 데이터 가져오기
        let baseAddress = CVPixelBufferGetBaseAddress(depthImage)
        let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self)
        
        // 3D 점을 저장할 배열
        var points3D = [SCNVector3]()
        
        // 각 픽셀에 대해
        for y in 0..<depthHeight {
            for x in 0..<depthWidth {
                let depthValue = floatBuffer?[y * depthWidth + x]
                
                // 예제: 일정 깊이 값 이상인 경우에만 3D 점 생성
                if let depthValue = depthValue, depthValue < 0.5 {
                    // 픽셀 좌표를 3D 공간 좌표로 변환
                    let point3D = sceneView.unprojectPoint(SCNVector3(x: Float(x), y: Float(y), z: depthValue))
                    points3D.append(point3D)
                }
            }
        }
        
        // points3D 배열에 있는 3D 점들을 이용하여 원하는 작업을 수행
        // 예제: 3D 점을 시각적으로 표시
        for point in points3D {
            let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.005))
            sphereNode.position = point
            parent.addChildNode(sphereNode)
        }
    */
        
        var x : Float = 0.0
        var y : Float = 0.0
        var z : Float = 0.0
        var lowestDot : Float = 0.0
        //get x,y,z in pointcloud
        let points = pointCloud.points
        let countPoint = points.count
        
        //sum x,y,z in pointcloud
        for point in points{
            x += Float(point.x)
            y += Float(point.y)
            z += Float(point.z)
            if point.y <= lowestDot{
                lowestDot = point.y
            }
        }
        
        //average x,y,z
        let aveX = x/Float(countPoint)
        let aveY = y/Float(countPoint)
        let aveZ = z/Float(countPoint)
        
        //
        if aveY < (lowestDot+0.05) {
            let aveNode = SCNNode()
            let aveMaterial = SCNMaterial()
            aveMaterial.diffuse.contents = UIColor.red
            aveNode.geometry = SCNSphere(radius: 0.01)
            aveNode.geometry?.firstMaterial = aveMaterial
            aveNode.position = SCNVector3(aveX,aveY,aveZ)
            parent.addChildNode(aveNode)
            DispatchQueue.main.async{
                self.textObject.text = "OK"
            }
        }else{
            DispatchQueue.main.async {
                self.textObject.text = "some obstacles found "
            }
        }
        

        
        //place the parentnode by stride()
        //from => The starting value to use for the sequence
        //to => end value to limit the sequence
        //by =>The amount to step by with each iteration
        //##this function will skip some cloudPoint##
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
        
        
        DispatchQueue.main.async {
            self.sceneView.scene.rootNode.addChildNode(parent)
            self.createdNodes.append(parent)
            self.textLowest.text = "lowest = \(lowestDot)"
            self.textHeight.text = "ave_height = \(aveY)"
        }
    }
    
    //renderer update by find new ARAnchor and SCNNode
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
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
                sceneView.scene.rootNode.addChildNode(lineNode)
                
                //create Text node
                let length = distance(transform1: transform1, transform2: transform2)
                let lengthText = "\(String(format: "%.2f", length))m"
                let textGeometry = SCNText(string: lengthText, extrusionDepth: 0.01)
                textGeometry.font = UIFont.systemFont(ofSize: 0.1)
                textGeometry.flatness = 0.1
                lengthNode = SCNNode(geometry: textGeometry)
                lengthNode.position = SCNVector3((nodeLine1.position.x+nodeLine2.position.x)/2, -0.9, (nodeLine1.position.z + nodeLine2.position.z)/2)
                //lengthNode.position = nodeLine1.position
                let billboardConstraint = SCNBillboardConstraint()
                lengthNode.constraints = [billboardConstraint]
                
                sceneView.scene.rootNode.addChildNode(lengthNode)
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
        print("wallA = \(wallA?.anchor) \n\nwallB = \(wallB?.anchor))\n\n")
        
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
            print("change wallA")
        }else{
            wallB = wall(anchor: anchor)
            print("change wallB")
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
        let distanceToAnchor = sqrt(dx*dx + dy*dy + dz*dz)
        print("distance From Camera = \(distanceToAnchor)")
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    func distanceBetweenAnchors(anchor1: ARAnchor, anchor2: ARAnchor) -> Float {
        let dx = anchor1.transform.columns.3.x - anchor2.transform.columns.3.x
        let dy = anchor1.transform.columns.3.y - anchor2.transform.columns.3.y
        let dz = anchor1.transform.columns.3.z - anchor2.transform.columns.3.z
        let distanceBetweenAnchors = sqrt(dx*dx + dy*dy + dz*dz)
        print("distance between Anchors = \(distanceBetweenAnchors)")
        return sqrt(dx*dx + dy*dy + dz*dz)
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
