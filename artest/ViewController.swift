import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
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
    
    ///for angle v1
    var overlayPoints = [CGPoint]()

    ///for angle v2
    var planeAnchors = [ARPlaneAnchor]()

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //nodeRemover(interval: 10, repeats: true, type: "all")
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        //sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        let scene = SCNScene()
        sceneView.scene = scene
        
        //for angles
        let totalPoints = 3
        // 간격을 더 적절하게 조정
        let gap = view.bounds.height / (CGFloat(totalPoints) * 2) // 예: 총 높이의 1/10
        // 시작점을 화면 중간 근처로 조정
        let startY = view.bounds.midY - gap * CGFloat(totalPoints / 2)

        overlayPoints = []

        for i in 0..<totalPoints {
            let y = startY + gap * CGFloat(i)
            let point = CGPoint(x: view.bounds.midX, y: y)
            overlayPoints.append(point)
        }

        addOverlayViews(points: overlayPoints)
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.frameSemantics.insert(.sceneDepth)
        sceneView.session.run(configuration)
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: setting renderers
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform else { return }
        let cameraPosition = simd_make_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        guard let pointCloudBefore = sceneView.session.currentFrame?.rawFeaturePoints else { return }
        let maxDistance: Float = 4.5
        let pointCloud = pointCloudBefore.points.filter { point in
            let distance = simd_distance(cameraPosition, point)
            return distance <= maxDistance && point.y <= (cameraPosition.y-0.3)
        }


        // for obstacles ==========================================================================================================================================
        let heightsForObstacles = pointCloud.map{$0.y}
        
        let ave = movingAverage(size: 8292)

        let obstacleIndex = heightsForObstacles.enumerated().compactMap { index, height in
            let avg = ave.add(height)
            return height > avg ? index : nil
        }
        
        let obstaclePoints = obstacleIndex.map { pointCloud[$0] }
        
        for point in obstaclePoints {
                    let angleNode = SCNNode()
                    angleNode.position = SCNVector3(point.x, point.y, point.z)
                    createdNodes.append(angleNode)
        }
        
        
        
        let obstacleLimit: Int = 50
        //DispatchQueue.main.async {
        //    self.textLowest.text = "obstacle limit = \(obstacleLimit)"
        //}
        
        if obstaclePoints.count > obstacleLimit{
            self.sceneView.scene.rootNode.addChildNode(createSpearNodeWithStride(pointCloud: obstaclePoints))
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

        

        
        // for floor ==========================================================================================================================================
        // グリッドフィルタリング
        let filteredPointCloud = filterPointCloud(pointCloud, gridSpacing: 0.05, cameraPosition: cameraPosition)
        
        let heightsForfloor = filteredPointCloud.map { $0.y }
        
        let floorIndex = heightsForfloor.enumerated().compactMap { index, height in
            let avg = ave.add(height)
            return height > avg ? index : nil
        }
        
        let floorPoints = floorIndex.map { filteredPointCloud[$0] }
        //スロープ検知処理のコード
        
        
        //sceneView.scene.rootNode.addChildNode(createSpearNodeWithStride(pointCloud: floorPoints))

        
        
        //for angle ==========================================================================================================================================
        
        let angleAverage = movingAverage(size: 5)

            if overlayPoints.count >= 2 {
                for i in 0..<(overlayPoints.count - 1) {
                    let point1 = self.performRaycast(from: overlayPoints[i])
                    let point2 = self.performRaycast(from: overlayPoints[i + 1])
                    if let p1 = point1, let p2 = point2 {
                        let angle = self.calculateAngle(p1, p2)
                        _ = angleAverage.add(angle) // 각도 추가 및 평균 업데이트
                    }
                }
            }

            let averageAngle = angleAverage.average() // 이동 평균 각도

            DispatchQueue.main.async {
                self.textView.text = "Moving average angle = \(averageAngle)"
            }


        

    }



    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        var angles = [Float]()
        if let planeAnchor = anchor as? ARPlaneAnchor {
            // Wall (vertical)
            if planeAnchor.alignment == .vertical{
                node.addChildNode(createWallNode(planeAnchor: planeAnchor))
                //DispatchQueue.main.async{
                //   self.textView.text = "Find \(planeAnchor.classification)\n name = \(planeAnchor.identifier)\n  eulerAngles = \(node.eulerAngles)"
                //}
                //nodeRemover(interval: 0, repeats: false, type: "line")
                //nodeRemover(interval: 0, repeats: false, type: "length")
            }
            // floor (horizontal)
            if planeAnchor.alignment == .horizontal {
                    let center = simd_float3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
                    let points: [simd_float3] = [
                        center,
                        simd_float3(center.x + planeAnchor.planeExtent.height/2, center.y, center.z),
                        simd_float3(center.x, center.y, center.z + planeAnchor.planeExtent.height/2), // 중심에서 앞쪽으로
                        simd_float3(center.x, center.y, center.z - planeAnchor.planeExtent.height/2)  // 중심에서 뒤쪽으로
                    ]

                    var angles = [Float]()
                    for point in points {
                        let raycastQuery = ARRaycastQuery(origin: point, direction: simd_float3(0, -1, 0), allowing: .estimatedPlane, alignment: .horizontal)
                        if let result = sceneView.session.raycast(raycastQuery).first {
                            let angle = calculateFloorAngle(result.worldTransform)
                            angles.append(angle)
                        }
                    }

                    if !angles.isEmpty {
                        let averageAngle = angles.reduce(0, +) / Float(angles.count)
                        DispatchQueue.main.async {
                            self.textLowest.text = "AveFloor Angle: \(averageAngle)"
                        }
                    }
                }
            
        }
        
        
        if wallA?.anchor != nil && wallB?.anchor != nil{
            let nodeLine1 = SCNNode()
            let nodeLine2 = SCNNode()
            var lengthNode = SCNNode()
            
            if let transform1 = wallA?.anchor.transform, let transform2 = wallB?.anchor.transform{
                
                nodeLine1.simdTransform = transform1
                nodeLine2.simdTransform = transform2
                
                let lineGeometry = SCNGeometry.line(from: nodeLine1.position, to: nodeLine2.position)
                let lineNode = SCNNode(geometry: lineGeometry)
                
                
                let length = distance(transform1: transform1, transform2: transform2)
                let lengthText = "\(String(format: "%.2f", length))m"
                let textGeometry = SCNText(string: lengthText, extrusionDepth: 0.01)
                textGeometry.font = UIFont.systemFont(ofSize: 0.2)
                textGeometry.flatness = 1
                lengthNode = SCNNode(geometry: textGeometry)
                lengthNode.position = SCNVector3((nodeLine1.position.x+nodeLine2.position.x)/2, -0.9, (nodeLine1.position.z + nodeLine2.position.z)/2)
                let billboardConstraint = SCNBillboardConstraint()
                lengthNode.constraints = [billboardConstraint]
            
                lineNode.name = "line"
                createdNodes.append(lineNode)
                sceneView.scene.rootNode.addChildNode(lineNode)
                
                lengthNode.name = "length"
                createdNodes.append(lengthNode)
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
    
    
    
    
    //MARK: for angle functions
    
    //for angle view
    func addOverlayViews(points: [CGPoint]) {
        for point in points {
            createAndAddView(at: point)
        }
    }

    func createAndAddView(at point: CGPoint) {
        let overlayView = UIView()
        overlayView.backgroundColor = .red
        overlayView.frame = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
        overlayView.layer.cornerRadius = 2.5
        view.addSubview(overlayView)
    }
    
    
    
    //for raycast
    func performRaycast(from point: CGPoint) -> simd_float4? {
            if let raycastQuery = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
               let result = sceneView.session.raycast(raycastQuery).first {
                return result.worldTransform.columns.3
            }
            return nil
        }

    func calculateAngle(_ point1: simd_float4, _ point2: simd_float4) -> Float {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        let dz = point2.z - point1.z
        let horizontalDistance = sqrt(dx*dx + dz*dz)
        let angleForFloor = atan2(dy, horizontalDistance)
        return angleForFloor * (180.0 / .pi)
    }

    func calculateFloorAngle(_ transform: matrix_float4x4) -> Float {
        let normal = transform.columns.2
        let angleRadians = acos(normal.y)
        return angleRadians * (180.0 / .pi)
    }
    
    //MARK: for floor
    //グリッド上に点群データをフィルタリング
    func filterPointCloud(_ pointCloud: [simd_float3], gridSpacing: Float, cameraPosition: simd_float3) -> [simd_float3] {
        // 最も低い点の高さを探す
        let minHeight = pointCloud.min(by: { $0.y < $1.y })?.y ?? 0
        let heightThreshold = minHeight + 0.2

        var filteredPoints = [simd_float3]()
        var grid = [String: Bool]()

        for point in pointCloud {
            let gridX = Int(floor(point.x / gridSpacing))
            let gridZ = Int(floor(point.z / gridSpacing))
            let gridKey = "\(gridX)_\(gridZ)"
            //カメラの位置から-1mの点群のみ取得
            let isBelowCamera = point.y <= (cameraPosition.y - 1.0)
            
            if isBelowCamera && point.y <= heightThreshold, grid[gridKey] == nil {
                filteredPoints.append(point)
                grid[gridKey] = true
            }
        }
        return filteredPoints
    }
    
    
     
    
    //MARK: -------------relate nodes-------------
    

    func nodeRemover(interval: TimeInterval, repeats: Bool, type: String){
        let removeType = {
            print("repeats =\(repeats), type = \(type)")
            
            for node in self.createdNodes {
                if node.name == type {
                    node.removeFromParentNode()
                }
            }
            
            switch type {
            case "line":
                print("case = line")
                self.createdNodes.removeAll(where: { $0.name == "line" })
            case "length":
                print("case = length")
                self.createdNodes.removeAll(where: { $0.name == "length" })
            case "wall":
                print("case = wall")
                self.createdNodes.removeAll(where: { $0.name == "wall" })
            case "spear":
                print("case = spear")
                self.createdNodes.removeAll(where: { $0.name == "spear" })
            default:
                print("case = default")
                let configuration = ARWorldTrackingConfiguration()
                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            }
        }

        if repeats == true {
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                DispatchQueue.main.async {
                    removeType()
                }
            }
        } else {
            DispatchQueue.main.async {
                removeType()
            }
        }
    }

    
    func createSpearNodeWithStride(pointCloud : [simd_float3]) -> SCNNode{
        
        let spearNode = SCNNode()
        for i in stride(from: 0, to: pointCloud.count, by: 10){
            let node = SCNNode()
            let point = pointCloud[i]
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.yellow
            node.geometry = SCNSphere(radius: 0.04)
            node.geometry?.firstMaterial = material
            node.position = SCNVector3(point.x, point.y, point.z)
            node.name = "spear"
            createdNodes.append(node)
            spearNode.addChildNode(node)
            
        }
        return spearNode
    }
    
    func createSpearNode(anchor: ARAnchor) -> SCNNode{
        let node = SCNNode()
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.yellow
        node.geometry = SCNSphere(radius: 0.01)
        node.geometry?.firstMaterial = material
        let anchorTransform = anchor.transform.columns.3
        node.position = SCNVector3(anchorTransform.x, anchorTransform.y, anchorTransform.z)
        node.name = "spear"
        createdNodes.append(node)
        return node
    }
    
    
    //MARK: -------------relate wall node-------------
    
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
        
        planeNode.name = "wall"
        createdNodes.append(planeNode)
        addWall(anchor: planeAnchor)
        
        //DispatchQueue.main.async {
        //    self.textView.text = "Find \(planeAnchor.classification)\n\n width = \(width)\n height = \(height)\n\n rotation = \(planeNode.rotation)"
        //}

        return planeNode
        }
    
    
    func addWall (anchor : ARAnchor){

        if isNext{
            wallA = wall(anchor: anchor)
        }else{
            wallB = wall(anchor: anchor)
        }
        isNext = !isNext
    }
    
    
    
    //MARK: -------------relate distance-------------

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
    
    let cameraLight = UseCameraLight()
    var isTorchOn = false // トーチの状態を追跡する変数
    @IBAction func toggleLightButtonPressed(_ sender: UIButton) {
        isTorchOn.toggle() // トーチの状態を切り替える
        cameraLight.toggleTorch(on: isTorchOn)
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
