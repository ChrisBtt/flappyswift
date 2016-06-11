//
//  GameViewController.swift
//  FlappySwift
//
//  Created by Nils Fischer on 06.06.16.
//  Copyright (c) 2016 iOS Dev Kurs Universität Heidelberg. All rights reserved.
//

import UIKit
import SpriteKit

class ViewController: UIViewController {
    
    var sceneView: SKView {
        return self.view as! SKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure scene view
//        sceneView.showsFPS = true
//        sceneView.showsNodeCount = true
//        sceneView.showsDrawCount = true

        // Present initial scene
        guard let flyScene = FlyScene(fileNamed: "FlyScene") else {
            return
        }
        flyScene.size = self.view.bounds.size
        sceneView.presentScene(flyScene)
    
    }

}
