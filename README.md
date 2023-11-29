BarrierVisonの障がい認識アルゴリズムを開発するリポジトリ
ここでテストを行ってからアプリに機能として実装する
できるだけ、スマホ１台で処理できるようにすることを目標としている。

[BarrierVison](https://github.com/e215402/RedBallPanchi)

## override func viewDidLoad()
ここはViewがロードされる前に実行される（AR画面が表示される直前）
```
Timer.scheduledTimer(withTimeInterval: 1330.0, repeats: true) { timer in
            DispatchQueue.main.async {
                for node in self.createdNodes {
                    node.removeFromParentNode()
                }
                self.createdNodes.removeAll()
            }
```
withTimeIntervalに設定した時間に全てのnodeを消す。

## override func viewWillAppear(_ animated: Bool)

ここはViewがローだされたときに実行される（AR画面が表示された時）
```
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        configuration.frameSemantics.insert(.sceneDepth)
        sceneView.session.run(configuration)
```
を使ってsessionを起動させる。

## func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)

ここはRealTimeで処理する関数を使ってARを表示する。60FPSでUpdateされる。

主に
```
guard let pointCloud = sceneView.session.currentFrame?.rawFeaturePoints else { return }
```

PointCloudを用いたDepthデータ(深度データ)を処理をする、

rawFeaturePointsでは情報量が足りないかもしれない。

今回では
pointCloudはmaxDiscanceでフィルタリングした距離だけの点だけ持っている。
生の情報はpointCloudBeforeを使う。

cameraPositionを使って現在のカメラの位置を求めることができる（member => x, y, z）

mainのnodeに追加するため、parent(SCNNode())を用意している。

```
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
```
で現在pointCloudで求めた点を表示することができる。
stride 関数で　byで宣言したIntのpointCloudを省略してARCameraに表示する。

## func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)

ここは新しいAnchorのためのSCNNodeを設置することができる場合のみUpdateされる。
主にSCNNode()を用いて、rootNodeにaddChildNodeの場合に使う。（仮想の物体を置く、仮想の線を引くなど）
didAdd nodeはviewWillAppearで設定したconfigurationによって変わる。

```
if let planeAnchor = anchor as? ARPlaneAnchor
```
で壁を認識して壁の情報を求める。

```
if wallA?.anchor != nil && wallB?.anchor != nil
```
で全域変数wallA,wallBに壁の情報がある場合、２つの壁に線を引く＋距離を測る。
## 自分で作成した関数の説明は省略する。（多分名前を読めばわかる）



