BarrierVisonの障がい認識アルゴリズムを開発するリポジトリ
ここでテストを行ってからアプリに機能として実装する

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

## func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)

ここは新しいAnchorのためのSCNNodeを設置することができる場合のみUpdateされる。
主にSCNNode()を用いて、rootNodeにaddChildNodeの場合に使う。（仮想の物体を置く、仮想の線を引くなど）
didAdd nodeはviewWillAppearで設定したconfigurationによって変わる。


自分で作成した関数の説明は省略する。（多分名前を読めばわかる）



