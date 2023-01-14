import UIKit
import SceneKit
import ARKit
import WebKit
//Notes: try captureDevicePosition

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var eyePositionIndicatorView: UIView!
    @IBOutlet weak var eyePositionIndicatorCenterView: UIView!
    @IBOutlet weak var blurBarView: UIVisualEffectView!
    @IBOutlet weak var lookAtPositionXLabel: UILabel!
    @IBOutlet weak var lookAtPositionYLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var clusterLabel: UILabel!
    @IBOutlet weak var chosenCluster: UILabel!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var keyBoardImageView: UIImageView!
    
    var faceNode: SCNNode = SCNNode()
    var cnt: [Int] = Array(repeating: 0, count: 10)
    var frameCount = 0
    var clusterString = ""
    var isBlink = false
    
    //Left and right eyes node
    var eyeLNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var eyeRNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    
    var lookAtTargetEyeLNode: SCNNode = SCNNode()
    var lookAtTargetEyeRNode: SCNNode = SCNNode()
    
    // Actual physical size
    let phoneScreenSize = CGSize(width: 0.0623908297, height: 0.135096943231532)
    
    // Actual point size
    let phoneScreenPointSize = CGSize(width: 834, height: 1194)
    var virtualPhoneNode: SCNNode = SCNNode()
    
    var virtualScreenNode: SCNNode = {
        
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        return SCNNode(geometry: screenGeometry)
    }()
    
    var eyeLookAtPositionXs: [CGFloat] = []
    
    var eyeLookAtPositionYs: [CGFloat] = []
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // Calibration
    var cornerOffsets = (topLeft: CGPoint(), topRight: CGPoint(), bottomLeft: CGPoint(), bottomRight: CGPoint())
    var transform: CGAffineTransform?
    
    var smoothEyeLookAtPosition = CGPoint()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Design Elements
        eyePositionIndicatorView.layer.cornerRadius = eyePositionIndicatorView.bounds.width / 2
        sceneView.layer.cornerRadius = 28
        eyePositionIndicatorCenterView.layer.cornerRadius = 4
        
        blurBarView.layer.cornerRadius = 36
        blurBarView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        self.view.bringSubviewToFront(eyePositionIndicatorView)
        
        
        messageTextView.layer.borderWidth = 1
        messageTextView.layer.cornerRadius = 10
                
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Setup Scenegraph
        sceneView.scene.rootNode.addChildNode(faceNode)
        sceneView.scene.rootNode.addChildNode(virtualPhoneNode)
        virtualPhoneNode.addChildNode(virtualScreenNode)
        faceNode.addChildNode(eyeLNode)
        faceNode.addChildNode(eyeRNode)
        eyeLNode.addChildNode(lookAtTargetEyeLNode)
        eyeRNode.addChildNode(lookAtTargetEyeRNode)
        
        // Set LookAtTargetEye at 3 meters away from the center of eyeballs to create segment vector
        lookAtTargetEyeLNode.position.z = 3
        lookAtTargetEyeRNode.position.z = 3
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }

        update(withFaceAnchor: faceAnchor)
    }
    
    // MARK: - update(ARFaceAnchor)
    
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        
        eyeRNode.simdTransform = anchor.rightEyeTransform
        eyeLNode.simdTransform = anchor.leftEyeTransform
        
        var eyeLLookAt = CGPoint()
        var eyeRLookAt = CGPoint()
        
        let heightCompensation: CGFloat = 312
        
        DispatchQueue.main.async { [self] in
            
            // Perform Hit test using the ray segments that are drawn by the center of the eyeballs to somewhere two meters away at direction of where users look at to the virtual plane that place at the same orientation of the phone screen
            
            let phoneScreenEyeRHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeRNode.worldPosition, to: self.eyeRNode.worldPosition, options: nil)
            
            let phoneScreenEyeLHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeLNode.worldPosition, to: self.eyeLNode.worldPosition, options: nil)
            
            print(self.phoneScreenSize.width);
            print(self.phoneScreenSize.height);
            
            //right eye hit test results
            for result in phoneScreenEyeRHitTestResults {
                
                eyeRLookAt.x = CGFloat(result.localCoordinates.x) / (self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width
                
                eyeRLookAt.y = CGFloat(result.localCoordinates.y) / (self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height + heightCompensation
            }
            
            //left eye hit test results
            for result in phoneScreenEyeLHitTestResults {
                
                eyeLLookAt.x = CGFloat(result.localCoordinates.x) / (self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width
                
                eyeLLookAt.y = CGFloat(result.localCoordinates.y) / (self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height + heightCompensation
            }
            
            let smoothThresholdNumber: Int = 50
            self.eyeLookAtPositionXs.append((eyeRLookAt.x + eyeLLookAt.x) / 2)
            self.eyeLookAtPositionYs.append(-(eyeRLookAt.y + eyeLLookAt.y) / 2)
            self.eyeLookAtPositionXs = Array(self.eyeLookAtPositionXs.suffix(smoothThresholdNumber))
            self.eyeLookAtPositionYs = Array(self.eyeLookAtPositionYs.suffix(smoothThresholdNumber))
            
            var smoothEyeLookAtPositionX = self.eyeLookAtPositionXs.average!
            var smoothEyeLookAtPositionY = self.eyeLookAtPositionYs.average!
            
            self.smoothEyeLookAtPosition = CGPoint(x: smoothEyeLookAtPositionX, y: smoothEyeLookAtPositionY)
            if let transform = self.transform {
                let transformedPoint = self.smoothEyeLookAtPosition.applying(transform)
                smoothEyeLookAtPositionX = transformedPoint.x
                smoothEyeLookAtPositionY = transformedPoint.y
            }
            
            // Update cursor position
            if(!isBlink){
                self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: smoothEyeLookAtPositionX - self.view.frame.width / 2, y: smoothEyeLookAtPositionY - self.view.frame.height / 2)
            }
        
            //self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: 0, y: 0)
            
            // update eye look at labels values
            let lookAtPositionXInt = (Int(round(smoothEyeLookAtPositionX + self.phoneScreenPointSize.width / 2)))
            self.lookAtPositionXLabel.text = "\(lookAtPositionXInt)"
            
            let lookAtPositionYInt = (Int(round(smoothEyeLookAtPositionY + self.phoneScreenPointSize.height / 2)))
            self.lookAtPositionYLabel.text = "\(lookAtPositionYInt)"
            
            //Find cluster that the points go in
            let clusterLabel = self.getCluster(posX: lookAtPositionXInt, posY: lookAtPositionYInt)
            //self.clusterLabel.text = "\(clusterLabel)"
            
                        
            //Increase the appearance of cluster in 120 frame
            if(clusterLabel != 0){
                cnt[clusterLabel] += 1
                self.frameCount += 1
            };
            
            //print(frameCount, clusterLabel)
            //print(view.frame.width);
            //print(view.frame.height);
            
            //print("\(frameCount) \(clusterLabel) \(cnt[clusterLabel])")
            
            var maxCount = 0
            var maxCluster = 0
            if(self.frameCount > 120){
                for i in 1...9{
                    if(cnt[i] >= maxCount){
                        maxCount = cnt[i]
                        maxCluster = i
                    }
                }
                self.frameCount = 0
                for i in 0...9{
                    cnt[i] = 0
                }
            }
            
            if(maxCluster != 0){
                print(maxCluster)
                clusterString += "\(maxCluster), "
                self.chosenCluster.text = clusterString
            }
            
            // Calculate distance of the eyes to the camera
            let distanceL = self.eyeLNode.worldPosition - SCNVector3Zero
            let distanceR = self.eyeRNode.worldPosition - SCNVector3Zero
            
            // Average distance from two eyes
            let distance = (distanceL.length() + distanceR.length()) / 2
            
            // Update distance label value
//            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
            
        }
        
    }
    
    func getCluster(posX: Int, posY: Int) -> Int{
        //top left and bottom right
        //x     y     x     y
        let corner = [389, 1325, 641, 1426,
                      641, 1325, 966, 1426,
                      966, 1325, 1227, 1426,
                      389, 1426, 641, 1539,
                      641, 1426, 966, 1539,
                      966, 1426, 1227, 1539,
                      389, 1539, 641, 1640,
                      641, 1539, 966, 1640,
                      966, 1539, 1227, 1640
        ]
        
        for row in 0...8{
            if(posX > corner[4 * row] && posX < corner[4 * row + 2]
               && posY > corner[4 * row + 1] && posY < corner[4 * row + 3]){
                return row + 1
            }
        }
        return 0
    }
    
    func detectEyeBlink(anchor: ARFaceAnchor) {
        let blinkLeft = anchor.blendShapes[.eyeBlinkLeft]
        let blinkRight = anchor.blendShapes[.eyeBlinkRight]

        if ((blinkLeft?.decimalValue ?? 0.0) + (blinkRight?.decimalValue ?? 0.0)) > 0.5 {
            isBlink = true
            //print("blinking")
        }
        else{
            isBlink = false
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        virtualPhoneNode.transform = (sceneView.pointOfView?.transform)!
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        update(withFaceAnchor: faceAnchor)
        
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            detectEyeBlink(anchor: faceAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        return node
    }
    
}

typealias ViewControllerTrackingCalibration = ViewController
extension ViewControllerTrackingCalibration {
    
    @IBAction func didPressCalibrate(_ sender: UIButton) {
        print("Calibrating \(sender.titleLabel!.text!)")
        switch sender.titleLabel?.text {
        case "TL":
            cornerOffsets.topLeft = smoothEyeLookAtPosition
        case "TR":
            cornerOffsets.topRight = smoothEyeLookAtPosition
        case "BL":
            cornerOffsets.bottomLeft = smoothEyeLookAtPosition
        case "BR":
            cornerOffsets.bottomRight = smoothEyeLookAtPosition
        default:
            break
        }
    }
        
    @IBAction func setTranslate(_ sender: Any) {
        guard cornerOffsets.topLeft != CGPoint.zero || cornerOffsets.topRight != CGPoint.zero || cornerOffsets.bottomLeft != CGPoint.zero else {
            print("Cannot calibrate without 3 points")
            return
        }
        let a = simd_double3x3(rows: [simd_double3(Double(cornerOffsets.topLeft.x),
                                                   Double(cornerOffsets.topLeft.y), 1),
                                      simd_double3(Double(cornerOffsets.topRight.x),
                                                   Double(cornerOffsets.topRight.y), 1),
                                      simd_double3(Double(cornerOffsets.bottomLeft.x),
                                                   Double(cornerOffsets.bottomLeft.y), 1)])
        let b = simd_double3x3(rows: [simd_double3(0, 0, 1),
                                      simd_double3(Double(view.frame.width), 0, 1),
                                      simd_double3(0, Double(view.frame.height), 1)])
        let x = simd_mul(a.inverse, b)
        transform = CGAffineTransform(a: CGFloat(x.columns.0.x), b: CGFloat(x.columns.1.x),
                                      c: CGFloat(x.columns.0.y), d: CGFloat(x.columns.1.y),
                                      tx: CGFloat(x.columns.0.z), ty: CGFloat(x.columns.1.z))
        print(transform ?? "No Transform")
    }
}
