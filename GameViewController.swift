//
//  GameViewController.swift
//  CrashThatCar
//
//  Created by Lara Carli on 9/30/16.
//  Copyright © 2016 Larisa Carli. All rights reserved.
//

struct PhysicsCategory {
	static let none: Int = 0
	static let floor: Int = -1
	static let car1: Int = 2
	static let car2: Int = 4
	static let barrier: Int = 8
	static let obstacle: Int = 16
	static let finishLine: Int = 32
}

let pi = Float(M_PI)

enum GameState { //not finite
	case preparingTheScene
	case tapToPlay
	case play
	case gameOver
}

import UIKit
import QuartzCore
import SceneKit
import SpriteKit


class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
	var scnView: SCNView!
	var deviceSize: CGSize!
	var raceScene: SCNScene?
	var gameOverScene: GameOverScene!
	
	
	//Player
	var player1Car: SCNNode?
	var player2Car: SCNNode?
	var player1StartingPosition: SCNVector3!
	var player2StartingPosition: SCNVector3!
	
	//Obstacle
	var obstacleArray: [SCNNode] = []
	let obstacleVelocity: Float = 10
	var readyToShoot: Bool = false
	var obstacleScene: SCNScene!
	var obstacle: SCNNode!
	let obstacleParticleSystem = SCNParticleSystem(named: "obstacleParticleSystem.scnp", inDirectory: "art.scnassets/Particles")!
	let obstacleExplodeParticleSystem = SCNParticleSystem(named: "obstacleExplodeParticleSystem.scnp", inDirectory: "art.scnassets/Particles")!
	
	//Camera
	var mainCameraSelfieStick: SCNNode?
	var mainCamera: SCNNode?
	
	//Playground and game
	let playgroundX: Float = 40 // ?
	let playgroundZ: Float = 20
	
	var lastTouchedLocation = CGPoint.zero
	var timeSinceLastTap: TimeInterval = 0
	
	var gameState: GameState = .preparingTheScene
	var tutorialFinished: Bool = false
	var sounds: [String:SCNAudioSource] = [:]
	var tapToPlayLogoPlane: SCNNode!
	

    override func viewDidLoad() {
        super.viewDidLoad()
		deviceSize = UIScreen.main.bounds.size
		gameOverScene = GameOverScene(gameViewController: self)
		
		setupView()
		setupScene()
		setupCars()
		setupCarBarriers()
		setupLines()
		setupCameras()
		setupSounds()
		setupTapToPlayLogo()
		
		prepareTheScene()
		setupObstacles()
    }
	
	//Setups:
	
	func setupView() {
		scnView = self.view as! SCNView!
		scnView.delegate = self
	}
	
	func setupScene() {
		raceScene = SCNScene(named: "art.scnassets/Scenes/raceScene.scn")
		scnView.scene = raceScene
		raceScene?.physicsWorld.contactDelegate = self
	}
	
	func setupCars() {
		player1Car = raceScene?.rootNode.childNode(withName: "player1Car reference", recursively: true)
		player2Car = raceScene?.rootNode.childNode(withName: "player2Car reference", recursively: true)
		
		for car in [player1Car, player2Car] { car?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil) }
		player1Car?.physicsBody?.categoryBitMask = PhysicsCategory.car1
		player2Car?.physicsBody?.categoryBitMask = PhysicsCategory.car2
		
		player1StartingPosition = player1Car?.presentation.position
		player2StartingPosition = player2Car?.presentation.position
		
		for car in [player1Car, player2Car] {
			car?.physicsBody?.collisionBitMask = PhysicsCategory.floor
			car?.physicsBody?.contactTestBitMask = PhysicsCategory.finishLine | PhysicsCategory.obstacle
			car?.physicsBody?.damping = 0
		}

	}
	
	func setupCarBarriers() {
		let player1CarBarrier = raceScene?.rootNode.childNode(withName: "player1Barrier", recursively: true)
		let player2CarBarrier = raceScene?.rootNode.childNode(withName: "player2Barrier", recursively: true)
		
		for barrier in [player1CarBarrier, player2CarBarrier] {
			barrier?.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
			barrier?.physicsBody?.categoryBitMask = PhysicsCategory.barrier
			barrier?.physicsBody?.collisionBitMask = PhysicsCategory.none
			barrier?.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
		}
	}
	
	func setupLines() {
		raceScene?.rootNode.enumerateChildNodes { node, stop in
			if node.name == "finishLine" {
				node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
				node.physicsBody?.categoryBitMask = PhysicsCategory.finishLine
				node.physicsBody?.collisionBitMask = PhysicsCategory.car1 | PhysicsCategory.car2
			}
		}
	}
	
	func setupCameras() {
		mainCameraSelfieStick = raceScene?.rootNode.childNode(withName: "mainCameraSelfieStick", recursively: true)
		mainCamera = raceScene?.rootNode.childNode(withName: "mainCamera", recursively: true)
		scnView.pointOfView = mainCamera
	}
	
	func setupTapToPlayLogo() {
		tapToPlayLogoPlane = raceScene?.rootNode.childNode(withName: "tapToPlayLogo", recursively: true)
	}
	
	func setupObstacles() {
		obstacleScene = SCNScene(named: "art.scnassets/Scenes/obstacleNormal.scn")
		obstacle = obstacleScene?.rootNode.childNode(withName: "obstacle", recursively: true)
		
		addObstacles()
	}
	
	func addObstacles() {
		var delayTime: Double = 0
		for i in 1...14 {
			for sign: Float in [-1.0, 1.0] {
				let randomPosition = SCNVector3(x: Float(i) * 3.3, y: 0.4, z: sign * Float(arc4random_uniform(UInt32(Int(playgroundZ/2 - 2.0))) + 1))
				
				let obstacleCopy = obstacle?.clone()
				obstacleCopy?.geometry = obstacle?.geometry?.copy() as? SCNGeometry
				obstacleCopy?.position = randomPosition
				
				obstacleCopy?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
				obstacleCopy?.physicsBody?.isAffectedByGravity = false
				obstacleCopy?.eulerAngles = SCNVector3(x: 5.0 * Float(i), y: Float(10 - i), z: 5.0 * Float(i) * sign)
				obstacleCopy?.physicsBody?.angularVelocity = SCNVector4(x: 0.5, y: 0.3, z: 0.2, w: 2.0)
				obstacleCopy?.physicsBody?.angularDamping = 0
				obstacleCopy?.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
				obstacleCopy?.physicsBody?.collisionBitMask = PhysicsCategory.none
				obstacleCopy?.physicsBody?.contactTestBitMask = PhysicsCategory.car1 | PhysicsCategory.car2 | PhysicsCategory.barrier
				
				obstacleArray.append(obstacleCopy!)
				
				DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: {
					self.raceScene!.rootNode.addChildNode(obstacleCopy!)
					self.playSound(node: obstacleCopy, name: "pop")
				})
				delayTime += 0.4
			}
		}
	}
	
	func prepareTheScene() {
		gameState = .preparingTheScene
		getTheCameraToShowTheScene()
	}
	
	//Tap To Play Logo:
	
	func showTapToPlayLogo() {
		let moveUp = SCNAction.moveBy(x: 0, y: 3.0, z: 0, duration: 1.0)
		let moveDown = moveUp.reversed()
		
		tapToPlayLogoPlane.isHidden = false
		self.playSound(node: tapToPlayLogoPlane, name: "pop")
		tapToPlayLogoPlane.runAction(SCNAction.repeatForever(SCNAction.sequence([moveUp, moveDown])))
		gameState = .tapToPlay
	}
	
	func hideTapToPlayLogo() {
		tapToPlayLogoPlane.removeAllActions()
		tapToPlayLogoPlane.isHidden = true
	}
	
	//Camera:
	
	func getTheCameraToShowTheScene() {
		let okPosition = mainCamera?.position
		let outPosition = SCNVector3(8, 35, 0)
		let outRightPosition = SCNVector3(37, 35, 0)
		
		let moveCameraOut = SCNAction.move(to: outPosition, duration: 3.0)
		let moveCameraToTheRight = SCNAction.move(to: outRightPosition, duration: 5.8)
		let moveCameraToTheLeft = SCNAction.move(to: outPosition, duration: 1.0)
		let moveCameraBack = SCNAction.move(to: okPosition!, duration: 2.0)
		let showTapToPlayLogo = SCNAction.run({node in self.showTapToPlayLogo()})
		let wait = SCNAction.wait(duration: 2.2)
		
		mainCamera?.runAction(SCNAction.sequence([moveCameraOut, moveCameraToTheRight, wait, moveCameraToTheLeft, SCNAction.group([moveCameraBack, wait]), showTapToPlayLogo]))
	}
	
	//Game:
	
	func startTheGame() {
		hideTapToPlayLogo()
		
		player1Car?.physicsBody?.velocity = SCNVector3(5, 0, 0)
		player2Car?.physicsBody?.velocity = SCNVector3(5, 0, 0)
		
		gameState = .play
	}
	
	func checkIfGameIsFinished(car: SCNNode, line: SCNNode) {
	}
	
	func obstacleCollidedWithCar(car: SCNNode, obstacle: SCNNode) {
		//gameOver! bring a table!
		if obstacle.name == "obstacleShot" {

		}
		
	}
	
	func gameOver(carWon: SCNNode) {
		let carWonName = carWon.presentation.position.z > 0 ? "first": "second"
		gameState = .gameOver
		stopTheCars()
		
		scnView.overlaySKScene = gameOverScene
		gameOverScene.popSpritesOnGameOver(carWon: carWonName)
		removeAllObstacles()
	}
	
	func replayGame() {
		gameOverScene.hideSprites()
		scnView.overlaySKScene = nil
		hideTapToPlayLogo()
		
		player1Car?.position = player1StartingPosition
		player2Car?.position = player2StartingPosition
		player1Car?.isHidden = false
		player2Car?.isHidden = false
		
		mainCameraSelfieStick?.position.x = 0
		addObstacles()
		prepareTheScene()
	}
	
	//Obstacles:
	
	func obstacleInBarrier(barrier: SCNNode, obstacle: SCNNode) {
		if obstacle.name == "obstacle" {
			obstacle.name = "obstacleReadyToBeShot" //with this name set, player can shot (drag) this obstacle, when he does that, its name becomes "obstacleShot"
		} else if obstacle.name == "obstacleShot" {
			obstacle.geometry?.materials.first?.diffuse.contents = UIColor.red
			obstacle.name = "obstacleReadyToBeRemoved"
		}
	}
	
	func shotTheObstacle(atVelocity velocity: SCNVector3) {
		for obstacle in obstacleArray {
			if obstacle.name == "obstacleInShot" {
				//obstacle.physicsBody?.velocity = velocity
				obstacle.addParticleSystem(obstacleParticleSystem)
				obstacle.physicsBody?.applyForce(velocity, asImpulse: true)
				obstacle.name = "obstacleShot"
			}
		}
	}
	
	func explodeObstacle(obstacle: SCNNode) {
		let position = obstacle.presentation.position
		let translationMatrix = SCNMatrix4MakeTranslation(position.x, position.y, position.z)
		
		raceScene?.addParticleSystem(obstacleExplodeParticleSystem, transform: translationMatrix)
		obstacle.removeFromParentNode()
	}
	
	func removeAllObstacles() {
		for obstacle in obstacleArray {
			explodeObstacle(obstacle: obstacle) //also removes it
		}
	}
	
	func calculateVelocity(point1: CGPoint, point2: CGPoint) -> SCNVector3 {
		let deltaY = Float(point1.y) - Float(point2.y)
		var angle = atan(deltaY / Float((point2.x - point1.x)))
		
		if point2.x < point1.x {
			if deltaY > 0 { angle -= pi/2 }
			else if deltaY < 0 { angle += pi/2 }
		} else if point2.x > point1.x {
			if deltaY > 0 { angle -= pi/2 }
			else if deltaY < 0 { angle += pi/2 }
		}
			
		return SCNVector3(obstacleVelocity * cos(angle), 0,  obstacleVelocity * sin(angle))
	}
	
	func stopTheCars() {
		player1Car?.physicsBody?.velocity = SCNVector3Zero
		//player1Car?.isHidden = true
		player2Car?.physicsBody?.velocity = SCNVector3Zero
		//player2Car?.isHidden = true
	}
	
	//Sounds:
	
	func setupSounds() {
		loadSound("pop", fileNamed: "art.scnassets/Sounds/pop.wav")
	}
	
	func loadSound(_ name:String, fileNamed:String) {
		let sound = SCNAudioSource(fileNamed: fileNamed)!
		sound.load()
		sounds[name] = sound
	}
	
	func playSound(node:SCNNode?, name:String) {
		if node != nil {
			if let sound = sounds[name] { node!.runAction(SCNAction.playAudio(sound, waitForCompletion: true)) }
		}
	}
	
	
	//Touches:
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		if gameState == .tapToPlay {
			startTheGame()
		} else if gameState == .play {
			for touch in touches {
				for result in scnView.hitTest(touch.location(in: scnView), options: nil) {
					if result.node.name == "obstacleReadyToBeShot" {
						lastTouchedLocation = touch.location(in: scnView)
						timeSinceLastTap = (event?.timestamp)!
						result.node.name = "obstacleInShot"
						readyToShoot = true
					}
				}
			}
		}
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if gameState == .play {
			if readyToShoot {
				let velocity = calculateVelocity(point1: lastTouchedLocation, point2: (touches.first?.location(in: scnView))!)
				shotTheObstacle(atVelocity: velocity)
				readyToShoot = false
			}
		}
	}
	
	//Scene Renderer:
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		if gameState == .play {
			let player1X = (player1Car?.presentation.position.x)!
			let player2X = (player2Car?.presentation.position.x)!
			let fastestCarX = player1X > player2X ? player1X : player2X
			mainCameraSelfieStick?.position.x = fastestCarX
		}
	}
	
	//Physics Contact:
	
	func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
		if gameState == .play {
			let nodeMaskA = contact.nodeA.physicsBody?.categoryBitMask
			let nodeMaskB = contact.nodeB.physicsBody?.categoryBitMask
			//print(nodeMaskA, nodeMaskB)
			
			if nodeMaskA == PhysicsCategory.barrier { obstacleInBarrier(barrier: contact.nodeA, obstacle: contact.nodeB) }
			else if nodeMaskB == PhysicsCategory.barrier { obstacleInBarrier(barrier: contact.nodeB, obstacle: contact.nodeA) }
			else if (nodeMaskA == PhysicsCategory.car1 || nodeMaskA == PhysicsCategory.car2) {
				if nodeMaskB == PhysicsCategory.obstacle { obstacleCollidedWithCar(car: contact.nodeA, obstacle: contact.nodeB) }
				else if nodeMaskB == PhysicsCategory.finishLine { gameOver(carWon: contact.nodeA) }
			} else if (nodeMaskB == PhysicsCategory.car1 || nodeMaskB == PhysicsCategory.car2) && nodeMaskA == PhysicsCategory.obstacle {
				if nodeMaskA == PhysicsCategory.obstacle { obstacleCollidedWithCar(car: contact.nodeB, obstacle: contact.nodeA) }
				else if nodeMaskA == PhysicsCategory.finishLine { gameOver(carWon: contact.nodeB) }
			}
		}
	}
	
	
	//Unrelevant variables and methods:
	
    override var shouldAutorotate: Bool { return true }
    override var prefersStatusBarHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("memory warning")
    }
}
