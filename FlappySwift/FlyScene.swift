//
//  GameScene.swift
//  FlappySwift
//
//  Created by Nils Fischer on 06.06.16.
//  Copyright (c) 2016 iOS Dev Kurs Universität Heidelberg. All rights reserved.
//

import SpriteKit
import GameplayKit

struct CollisionCategory {
    typealias CategoryBitMask = UInt32
    
    static let world: CategoryBitMask = 1 << 0
    static let bird: CategoryBitMask = 1 << 1
    static let obstacle: CategoryBitMask = 1 << 2
    static let score: CategoryBitMask = 1 << 3
    
}

class FlyScene: SKScene {
    
    
    // MARK: Constants
    
    /// The bird's distance from the left side of the screen
    private static let birdPosition: CGFloat = 100
    /// The impulse the bird gains with each flap, i.e. each tap on the screen, in Newton-seconds
    private static let impulseOnFlap: CGFloat = 500
    /// The time between spawing obstacles, in seconds
    private static let obstacleSpawnDelay: NSTimeInterval = 1.5
    /// The gap between the upper and lower part of the obstacle where the bird may safely fly through, in points
    private static let obstacleGap: CGFloat = 200
    /// The amount the obstacle may be shifted upwards or downwards randomly, in points
    private static let obstaclePositionVariance: CGFloat = 150
    /// The movement speed of the obstacles, in points per second
    private static let obstacleSpeed: CGFloat = 100
    
    
    // MARK: Lifecycle
    
    private lazy var gameStateMachine: GKStateMachine = {
        return GKStateMachine(states: [
            PrepareFlyingState(scene: self),
            FlyingState(scene: self),
            GameOverState(scene: self),
            ])
    }()

    override func didMoveToView(view: SKView) {
        super.didMoveToView(view)
        
        physicsWorld.contactDelegate = self
        
        self.addChild(background)
        self.addChild(scoreLabel)
        self.addChild(bird)
        shaking.addChild(obstacles)
        shaking.addChild(ground)
        self.addChild(shaking)
        
        gameStateMachine.enterState(PrepareFlyingState.self)
    }
    
    
    // MARK: User Interaction
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        switch gameStateMachine.currentState {
            
        case _ as PrepareFlyingState, _ as GameOverState:
            guard shaking.actionForKey("shaking") == nil else {
                break
            }
            gameStateMachine.enterState(FlyingState.self)
            fallthrough
            
        case _ as FlyingState:
            bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: FlyScene.impulseOnFlap))
            
        default:
            break
        }
    }
    
    override func update(currentTime: CFTimeInterval) {
        // update any game logic
    }

    private func birdDidHitObstacle() {
        gameStateMachine.enterState(GameOverState.self)
    }
    
    private func increaseScore() {
        guard let flyingState = gameStateMachine.currentState as? FlyingState else {
            return
        }

        flyingState.score += 1
        
        let scoreParticleEmitter = self.scoreParticleEmitter.copy() as! SKEmitterNode
        bird.addChild(scoreParticleEmitter)
        scoreParticleEmitter.runAction(emitScoreExplosion)
    }
    
    private lazy var scoreParticleEmitter: SKEmitterNode = {
        let emitter = SKEmitterNode(fileNamed: "ScoreParticles")!
        emitter.targetNode = self
        return emitter
    }()
    private lazy var emitScoreExplosion: SKAction = {
        .sequence([
            .waitForDuration(1),
            .removeFromParent(),
            ])
    }()
    
    
    // MARK: Game Elements
    
    /// MARK: The player character
    private var bird: SKSpriteNode = {
        let sprite = SKSpriteNode(imageNamed: "bird-01")
        let physicsBody = SKPhysicsBody(circleOfRadius: sprite.size.width / 2)
        physicsBody.mass = 1
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = CollisionCategory.bird
        physicsBody.collisionBitMask = CollisionCategory.world | CollisionCategory.obstacle
        physicsBody.contactTestBitMask = CollisionCategory.obstacle | CollisionCategory.score
        sprite.physicsBody = physicsBody
        sprite.constraints = [ SKConstraint.positionX(SKRange(value: FlyScene.birdPosition, variance: 0)) ]
        return sprite
    }()
    private let animateFlappingBird: SKAction = {
        let birdTextures = SKTextureAtlas(named: "bird")
        return .repeatActionForever(.animateWithTextures(birdTextures.textureNames.sort().map({ birdTextures.textureNamed($0) }), timePerFrame: 0.2))
    }()
    private let birdHover: SKAction = {
        let moveUp = SKAction.moveByX(0, y: 15, duration: 0.8)
        moveUp.timingMode = .EaseInEaseOut
        let moveDown = SKAction.moveByX(0, y: -15, duration: 0.8)
        moveDown.timingMode = .EaseInEaseOut
        return .repeatActionForever(.sequence([
            moveUp,
            moveDown,
            ]))
    }()
    
    private let obstaclePositionRandomSource = GKARC4RandomSource()

    /// Holds all obstacles to control their shared properties such as speed
    private let obstacles: SKNode = {
        let node = SKNode()
        return node
    }()
    
    private let upperObstacleTexture = SKTexture(imageNamed: "PipeDown")
    private let lowerObstacleTexture = SKTexture(imageNamed: "PipeUp")

    /// Creates an obstacles and moves it across the screen
    private lazy var spawnObstacle: SKAction = {
        return SKAction.runBlock {
            let upperObstacle = SKSpriteNode(texture: self.upperObstacleTexture)
            upperObstacle.anchorPoint = CGPoint(x: 0, y: 0)
            upperObstacle.centerRect = CGRect(x: 0, y: 20.0/160, width: 1, height: 140.0/160)
            upperObstacle.yScale = self.size.height / upperObstacle.size.height
            let lowerObstacle = SKSpriteNode(texture: self.lowerObstacleTexture)
            lowerObstacle.anchorPoint = CGPoint(x: 0, y: 1)
            lowerObstacle.centerRect = CGRect(x: 0, y: 0, width: 1, height: 140.0/160)
            lowerObstacle.yScale = self.size.height / lowerObstacle.size.height

            let upperPhysicsBody = SKPhysicsBody(edgeLoopFromRect: upperObstacle.frame)
            upperPhysicsBody.categoryBitMask = CollisionCategory.obstacle
            upperObstacle.physicsBody = upperPhysicsBody
            let lowerPhysicsBody = SKPhysicsBody(edgeLoopFromRect: lowerObstacle.frame)
            lowerPhysicsBody.categoryBitMask = CollisionCategory.obstacle
            lowerObstacle.physicsBody = lowerPhysicsBody
            
            let positionMean: CGFloat = self.size.height / 2
            let position: CGFloat = positionMean + CGFloat(self.obstaclePositionRandomSource.nextUniform()) * obstaclePositionVariance
            upperObstacle.position = CGPoint(x: 0, y: position + obstacleGap / 2)
            lowerObstacle.position = CGPoint(x: 0, y: position - obstacleGap / 2)
            
            let scoreLine = SKNode()
            let scorePhysicsBody = SKPhysicsBody(edgeFromPoint: CGPoint(x: upperObstacle.size.width, y: 0), toPoint: CGPoint(x: 0, y: self.size.height))
            scorePhysicsBody.categoryBitMask = CollisionCategory.score
            scoreLine.physicsBody = scorePhysicsBody
            
            let node = SKNode()
            node.addChild(upperObstacle)
            node.addChild(lowerObstacle)
            node.addChild(scoreLine)
            
            node.runAction(self.moveObstacle)
            self.obstacles.addChild(node)
        }
    }()
    private lazy var moveObstacle: SKAction = {
        let distance: CGFloat = self.size.width + self.upperObstacleTexture.size().width
        return .sequence([
            .moveTo(CGPoint(x: self.size.width, y: 0), duration: 0),
            .moveBy(CGVector(dx: -distance, dy: 0), duration: Double(distance / obstacleSpeed)),
            .removeFromParent(),
        ])
    }()
    private lazy var spawnObstaclesForever: SKAction = {
        .repeatActionForever(.sequence([
            self.spawnObstacle,
            .waitForDuration(obstacleSpawnDelay),
        ]))
    }()

    private let groundTexture = SKTexture(imageNamed: "ground")

    private lazy var ground: SKNode = {
        let node = SKNode()
        for i in (0...Int(ceil(self.size.width / self.groundTexture.size().width))) {
            let sprite = SKSpriteNode(texture: self.groundTexture)
            let physicsBody = SKPhysicsBody(edgeLoopFromRect: sprite.frame)
            physicsBody.categoryBitMask = CollisionCategory.world
            sprite.physicsBody = physicsBody
            sprite.position = CGPoint(x: CGFloat(i) * self.groundTexture.size().width, y: 0)
            node.addChild(sprite)
        }
        node.runAction(.repeatActionForever(self.moveGround))
        return node
    }()
    private lazy var moveGround: SKAction = {
        let distance: CGFloat = self.groundTexture.size().width
        return SKAction.sequence([
            .moveBy(CGVector(dx: -distance, dy: 0), duration: Double(distance / obstacleSpeed)),
            .moveBy(CGVector(dx: distance, dy: 0), duration: 0),
        ])
    }()

    private let backgroundTexture = SKTexture(imageNamed: "background")
    private lazy var background: SKNode = {
        let node = SKNode()
        for i in (0...Int(ceil(self.size.width / self.backgroundTexture.size().width))) {
            let sprite = SKSpriteNode(texture: self.backgroundTexture)
            sprite.position = CGPoint(x: CGFloat(i) * self.backgroundTexture.size().width, y: self.groundTexture.size().height - 2)
            node.addChild(sprite)
        }
        node.runAction(.repeatActionForever(self.moveBackground))
        return node
    }()
    private lazy var moveBackground: SKAction = {
        let distance: CGFloat = self.backgroundTexture.size().width
        return SKAction.sequence([
            .moveBy(CGVector(dx: -distance, dy: 0), duration: Double(distance / (obstacleSpeed / 3))),
            .moveBy(CGVector(dx: distance, dy: 0), duration: 0),
            ])
    }()
    
    private let shaking = SKNode()
    
    
    // MARK: Interface Elements
    
    private lazy var scoreLabel: SKLabelNode = {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.position = CGPoint(x: self.frame.midX, y: self.size.height / 2)
        return label
    }()
    
}


// MARK: - Game States

class GameState: GKState {
    
    let scene: FlyScene
    
    init(scene: FlyScene) {
        self.scene = scene
    }
    
}

class PrepareFlyingState: GameState {
    
    override func isValidNextState(stateClass: AnyClass) -> Bool {
        return stateClass == FlyingState.self
    }
    
    override func didEnterWithPreviousState(previousState: GKState?) {
        scene.ground.speed = 1
        scene.background.speed = 1
        scene.obstacles.speed = 0
        scene.bird.physicsBody?.dynamic = false
        scene.bird.position = CGPoint(x: FlyScene.birdPosition, y: scene.size.height / 2)
        // hover animation
        scene.bird.runAction(scene.birdHover, withKey: "hover")
        scene.bird.runAction(scene.animateFlappingBird, withKey: "animateFlapping")
    }
    
}

class FlyingState: GameState {
    
    private var score = 0 {
        didSet {
            scene.scoreLabel.text = String(score)
        }
    }
    
    override func isValidNextState(stateClass: AnyClass) -> Bool {
        return stateClass == GameOverState.self
    }
    
    override func didEnterWithPreviousState(previousState: GKState?) {
        score = 0
        
        scene.ground.speed = 1
        scene.background.speed = 1
        
        scene.bird.removeActionForKey("hover")
        scene.bird.physicsBody?.dynamic = true

        scene.obstacles.runAction(.sequence([
            .waitForDuration(3),
            scene.spawnObstaclesForever,
            ]), withKey: "spawnObstacles")
        scene.obstacles.speed = 1
        
        switch previousState {
        
        case _ as GameOverState:
            scene.obstacles.removeAllChildren()
            scene.bird.runAction(scene.animateFlappingBird, withKey: "animateFlapping")
            
        default:
            break
        }
    }

}

class GameOverState: GameState {
    
    override func isValidNextState(stateClass: AnyClass) -> Bool {
        return stateClass == FlyingState.self
    }

    override func didEnterWithPreviousState(previousState: GKState?) {
        scene.ground.speed = 0
        scene.background.speed = 0
        scene.obstacles.speed = 0
        scene.bird.removeActionForKey("animateFlapping")
        scene.shaking.runAction(SKAction.shake(1), withKey: "shaking")
    }

}


// MARK: - Physics Contact Delegate

extension FlyScene: SKPhysicsContactDelegate {
    
    func didBeginContact(contact: SKPhysicsContact) {
        switch (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask) {
            
        case let (a, b) where
            (a & CollisionCategory.bird != 0 && b & CollisionCategory.obstacle != 0) ||
            (b & CollisionCategory.bird != 0 && a & CollisionCategory.obstacle != 0):
            birdDidHitObstacle()
            
        default:
            break
        }
        
    }
    
    func didEndContact(contact: SKPhysicsContact) {
        switch (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask) {
            
        case let (a, b) where
            (a & CollisionCategory.bird != 0 && b & CollisionCategory.score != 0) ||
            (b & CollisionCategory.bird != 0 && a & CollisionCategory.score != 0):
            increaseScore()
            
        default:
            break
        }
    }
    
}


// MARK: - Shake Action

extension SKAction {
    
    class func shake(duration: NSTimeInterval, amplitudeX: Int = 3, amplitudeY: Int = 3) -> SKAction {
        let shakeDuration: NSTimeInterval = 0.015
        let numberOfShakes = duration / (shakeDuration * 2)
        var movements: [SKAction] = []
        for _ in (1...Int(numberOfShakes)) {
            let dx = CGFloat(arc4random_uniform(UInt32(amplitudeX))) - CGFloat(amplitudeX / 2)
            let dy = CGFloat(arc4random_uniform(UInt32(amplitudeY))) - CGFloat(amplitudeY / 2)
            let movement = SKAction.moveByX(dx, y: dy, duration: shakeDuration)
            movements.append(movement)
            movements.append(movement.reversedAction())
        }
        return .sequence(movements)
    }
}
