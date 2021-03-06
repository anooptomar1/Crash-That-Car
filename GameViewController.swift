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
	static let car: Int = 2
	static let speedUpObstacle: Int = 4
	static let barrier: Int = 8
	static let obstacle: Int = 16
	static let finishLine: Int = 32
	static let borderLine: Int = 64
	static let middleLine: Int = 128
}

struct Obstacle {
	static let normal: String = "normal"
	static let inBarrier: String = "inBarrier"
	static let beingShotFromPlayer1: String = "beingShotFromPlayer1"
	static let beingShotFromPlayer2: String = "beingShotFromPlayer2"
	static let shotFromPlayer1: String = "shotFromPlayer1"
	static let shotFromPlayer2: String = "shotFromPlayer2"
	static let readyToBeExploded: String = "readyToBeExploded"
}

let pi = Float(M_PI)

enum GameState { //not finite
	case preparingTheScene
	case tapToPlay
	case showingTutorial
	case countDown
	case play
	case gameOver
	case gameOverTapToPlay
}

import UIKit
import QuartzCore
import SceneKit
import SpriteKit
import ModelIO
import SceneKit.ModelIO


class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
	var scnView: SCNView!
	var deviceSize: CGSize!
	var raceScene: SCNScene?
	var gameOverScene: GameOverScene!
	
	
	//Cars
	var car1Node: SCNNode?
	var car2Node: SCNNode?
	var player1StartingPosition: SCNVector3!
	var player2StartingPosition: SCNVector3!
	let carVelocityMagnitude = 1.2
	
	var barrier1: SCNNode!
	var barrier2: SCNNode!
	var barrier2StartingPosition: SCNVector3!
	var barrier1StartingPosition: SCNVector3!
	
	var smokeEmitterArray: [SCNNode] = []
	
	//Obstacle
	var obstacleArray: [SCNNode] = []
	let obstacleVelocity: Float = 2.0
	var readyToShoot: Bool = false
	var obstacleScene: SCNScene!
	var obstacleNode: SCNNode!
	
	var speedUpObstacleScene: SCNScene!
	var speedUpObstacleNode: SCNNode!
	var speedUpObstacleArray: [SCNNode] = []
	
	let obstacleParticleSystem = SCNParticleSystem(named: "obstacleParticleSystem.scnp", inDirectory: "art.scnassets/Particles")!
	let obstacleExplodeParticleSystem = SCNParticleSystem(named: "obstacleExplodeParticleSystem.scnp", inDirectory: "art.scnassets/Particles")!
	let obstacleExplodeBigParticleSystem = SCNParticleSystem(named: "obstacleExplodeBigParticleSystem.scnp", inDirectory: "art.scnassets/Particles")!
	let obstacleReadyToShootParticleSystem = SCNParticleSystem(named: "readyToShoot", inDirectory: "art.scnassets/Particles")!
	let carSmokeParticleSystem = SCNParticleSystem(named: "carSmoke.scnp", inDirectory: "art.scnassets/Particles")!
	let speedUpObstacleParticleSystem = SCNParticleSystem(named: "speedUp.scnp", inDirectory: "art.scnassets/Particles")!
	let speedUpObstacleExplodeParticleSystem = SCNParticleSystem(named: "speedUpObstacleExplode", inDirectory: "art.scnassets/Particles")!
	let obstacleReadyToExplodeParticleSystem = SCNParticleSystem(named: "obstacleReadyToExplode", inDirectory: "art.scnassets/Particles")!
	
	//Camera
	var mainCamera: SCNNode?
	var sideCamera: SCNNode?
	
	//Playground and game
	let playgroundZ: Float = 24
	var lastTouchedLocation = CGPoint.zero
	
	var gameState: GameState = .preparingTheScene
	var tutorialFinished: Bool = false
	var sounds: [String:SCNAudioSource] = [:]
	
	//Controllers:
	var controllersArray: [SCNNode] = []
	var player1LeftController: SCNNode!
	var player1RightController: SCNNode!
	var player2LeftController: SCNNode!
	var player2RightController: SCNNode!
	
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
		setupControllers()
		
		prepareTheScene()
		setupObstacles()
		
	}
	
	//Setups:
	
	func setupView() {
		scnView = self.view as! SCNView!
		scnView.delegate = self
		//scnView.debugOptions = SCNDebugOptions.showPhysicsShapes
	}
	
	func setupScene() {
		raceScene = SCNScene(named: "art.scnassets/Scenes/raceScene.scn")
		scnView.scene = raceScene
		scnView.overlaySKScene = gameOverScene
		raceScene?.physicsWorld.contactDelegate = self
	}
	
	func setupCars() {
		car1Node = raceScene?.rootNode.childNode(withName: "player1Car reference", recursively: true)
		car2Node = raceScene?.rootNode.childNode(withName: "player2Car reference", recursively: true)
		
		for car in [car1Node, car2Node] {
			car?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
			car?.physicsBody?.isAffectedByGravity = true
			car?.physicsBody?.categoryBitMask = PhysicsCategory.car
			car?.physicsBody?.collisionBitMask = PhysicsCategory.floor | PhysicsCategory.borderLine | PhysicsCategory.middleLine
			car?.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.finishLine | PhysicsCategory.speedUpObstacle
			car?.physicsBody?.damping = 0
			car?.physicsBody?.angularDamping = 1
		}
		
		raceScene?.rootNode.enumerateChildNodes { node, stop in 
			if node.name == "smokeEmitter" { smokeEmitterArray.append(node) }
		}
		
		player1StartingPosition = car1Node?.presentation.position
		player2StartingPosition = car2Node?.presentation.position
		
	}
	
	func setupCarBarriers() {
		barrier1 = raceScene?.rootNode.childNode(withName: "car1Barrier reference", recursively: true)
		barrier2 = raceScene?.rootNode.childNode(withName: "car2Barrier reference", recursively: true)
		
		for barrier in [barrier1, barrier2] {
			barrier?.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
			barrier?.physicsBody?.categoryBitMask = PhysicsCategory.barrier
			barrier?.physicsBody?.collisionBitMask = PhysicsCategory.none
			barrier?.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
		}
		
		barrier1StartingPosition = barrier1.position
		barrier2StartingPosition = barrier2.position
	}
	
	func setupLines() {
		let finishLine = raceScene?.rootNode.childNode(withName: "finishLine", recursively: true)
		finishLine?.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
		finishLine?.physicsBody?.categoryBitMask = PhysicsCategory.finishLine
		finishLine?.physicsBody?.collisionBitMask = PhysicsCategory.none
		finishLine?.physicsBody?.contactTestBitMask = PhysicsCategory.car
		
		let borderLineLeft = raceScene?.rootNode.childNode(withName: "borderLineLeft", recursively: true)
		let borderLineRight = raceScene?.rootNode.childNode(withName: "borderLineRight", recursively: true)
		
		for borderLine in [borderLineLeft, borderLineRight] {
			borderLine?.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
			borderLine?.physicsBody?.categoryBitMask = PhysicsCategory.borderLine
			borderLine?.physicsBody?.collisionBitMask = PhysicsCategory.car
			borderLine?.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
		}
		
		let middleLine = raceScene?.rootNode.childNode(withName: "middleLine", recursively: true)
		middleLine?.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
		middleLine?.physicsBody?.categoryBitMask = PhysicsCategory.middleLine
		middleLine?.physicsBody?.collisionBitMask = PhysicsCategory.car
		middleLine?.physicsBody?.contactTestBitMask = PhysicsCategory.none
	}
	
	func setupCameras() {
		mainCamera = raceScene?.rootNode.childNode(withName: "mainCamera", recursively: true)
		scnView.pointOfView = mainCamera
		
		sideCamera = raceScene?.rootNode.childNode(withName: "sideCamera", recursively: true)
	}
	
	//Controllers:
	
	func setupControllers() {
		player1LeftController = raceScene?.rootNode.childNode(withName: "player1Left", recursively: true)
		controllersArray.append(player1LeftController)
		player1RightController = raceScene?.rootNode.childNode(withName: "player1Right", recursively: true)
		controllersArray.append(player1RightController)
		player2LeftController = raceScene?.rootNode.childNode(withName: "player2Left", recursively: true)
		controllersArray.append(player2LeftController)
		player2RightController = raceScene?.rootNode.childNode(withName: "player2Right", recursively: true)
		controllersArray.append(player2RightController)
		
		hideControllers()
	}
	
	func showControllers() {
		for controller in controllersArray { controller.isHidden = false }
	}
	func hideControllers() {
		for controller in controllersArray { controller.isHidden = true }
	}
	
	func touched(controller: SCNNode) {
		let zComponentIncrease: Float = 0.2
		
		switch (controller.name)! {
			case "player1Left": car1Node?.physicsBody?.velocity.z -= zComponentIncrease
			case "player1Right": car1Node?.physicsBody?.velocity.z += zComponentIncrease
			case "player2Left": car2Node?.physicsBody?.velocity.z -= zComponentIncrease
			case "player2Right": car2Node?.physicsBody?.velocity.z += zComponentIncrease
			default: return
		}
	}
	
	
	//Camera:
	
	func getTheCameraToShowTheScene() {
		scnView.pointOfView = sideCamera
	}
	
	//Game:
	
	func prepareTheScene() {
		gameState = .preparingTheScene
		getTheCameraToShowTheScene()
	}
	
	func startTheGame() {
		
		scnView.overlaySKScene = nil
		
		self.startTheCar()
		self.gameState = .play
		
		showControllers()
	}
	
	func replayGame() {
		gameOverScene.hideSprites()
		
		stopTheCars()
		
		barrier1?.position = barrier1StartingPosition
		barrier2?.position = barrier2StartingPosition
		
		car1Node?.isHidden = false
		car2Node?.isHidden = false
		
		mainCamera?.position.x = 0
		addObstacles()
		prepareTheScene()
	}
	
	func gameOver(carWon: SCNNode, atFinishLine: Bool) {
		gameState = .gameOver
		stopTheCars()
		hideControllers()
		
		let carWonName: String!
		
		if atFinishLine {
			carWonName = carWon.presentation.position.z > 0 ? "first": "second"
			playSound(node: mainCamera, name: "applause")
		} else {
			let carThatGotHit = carWon.presentation.position.z > 0 ? "first": "second"
			carWonName = carThatGotHit == "first" ? "second" : "first"
		}
		
		scnView.overlaySKScene = gameOverScene
		gameOverScene.popSpritesOnGameOver(carWon: carWonName)
		removeAllObstacles()
		
	}
	
	
	//Obstacles:
	
	func setupObstacles() {
		obstacleScene = SCNScene(named: "art.scnassets/Scenes/obstacleNormal.scn")
		obstacleNode = obstacleScene?.rootNode.childNode(withName: "obstacle", recursively: true)
		
		speedUpObstacleScene = SCNScene(named: "art.scnassets/Scenes/speedUpObstacle.scn")
		speedUpObstacleNode = speedUpObstacleScene?.rootNode.childNode(withName: "speedUpObstacle", recursively: true)
		
		addObstacles()
	}
	
	func addObstacles() {
		var delayTime: Double = 0.5
		
		for i in 0...4 {
			for sign: Float in [-1.0, 1.0] {
				let randomPosition = SCNVector3(x: Float(i) * 32.0 + 9.0, y: 1.4, z: sign * Float(arc4random_uniform(UInt32(Int(playgroundZ/2 - 2.0))) + 1))
				
				let obstacleCopy = obstacleNode?.copy() as? SCNNode
				obstacleCopy?.position = randomPosition
				obstacleCopy?.name = Obstacle.normal
				
				obstacleCopy?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
				
				obstacleCopy?.physicsBody?.isAffectedByGravity = false
				obstacleCopy?.eulerAngles = SCNVector3(x: 15.0 * Float(i), y: Float(10 - i), z: 5.0 * Float(i) * sign)
				obstacleCopy?.physicsBody?.angularVelocity = SCNVector4(x: 0.5, y: 0.3, z: 0.2, w: 1.0)
				obstacleCopy?.physicsBody?.angularDamping = 0
				obstacleCopy?.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
				obstacleCopy?.physicsBody?.collisionBitMask = PhysicsCategory.obstacle
				obstacleCopy?.physicsBody?.contactTestBitMask = PhysicsCategory.car | PhysicsCategory.barrier | PhysicsCategory.borderLine
				
				obstacleArray.append(obstacleCopy!)
				
				DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: {
					self.raceScene!.rootNode.addChildNode(obstacleCopy!)
					self.playSound(node: obstacleCopy, name: "pop")
				})
				delayTime += 0.3
			}
		}
		
		for i in 0...2 {
			for sign: Float in [-1, 1] {
				let speedUpObstacleCopy = speedUpObstacleNode?.copy() as? SCNNode
				speedUpObstacleCopy?.position = SCNVector3(x: Float(i) * 40.0, y: 1.3, z: sign * Float(arc4random_uniform(UInt32(Int((playgroundZ + 5)/2 - 2.0))) + 1))
				speedUpObstacleCopy?.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
				speedUpObstacleCopy?.physicsBody?.categoryBitMask = PhysicsCategory.speedUpObstacle
				speedUpObstacleCopy?.physicsBody?.collisionBitMask = PhysicsCategory.none
				speedUpObstacleCopy?.physicsBody?.contactTestBitMask = PhysicsCategory.car
				speedUpObstacleArray.append(speedUpObstacleCopy!)
				
				
				DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: {
					self.raceScene?.rootNode.addChildNode(speedUpObstacleCopy!)
					self.playSound(node: speedUpObstacleCopy, name: "pop")
					speedUpObstacleCopy?.addParticleSystem(self.speedUpObstacleParticleSystem)
				})
				delayTime += 0.3
			}
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + delayTime + 0.5, execute: {
			self.gameOverScene.showTapToPlayLogo()
		})
	}
	
	
	func obstacleCollidedWithCar(car: SCNNode, obstacle: SCNNode) {
		let obstacleBitMask = obstacle.physicsBody?.categoryBitMask
		
		if obstacleBitMask == PhysicsCategory.obstacle {
			explodeObstacleBig(obstacle: obstacle)
			
			car.physicsBody?.velocity.x -= 0.1
			
			
		} else if obstacleBitMask == PhysicsCategory.speedUpObstacle {
			explodeObstacle(obstacle: obstacle, speedUpType: true)
			car.physicsBody?.velocity.x += 0.1
		
		}
	}
	
	func obstacleInBarrier(barrier: SCNNode, obstacle: SCNNode) {
		if obstacle.name == Obstacle.normal { //player can shot the obstacle at the other player
			obstacle.name = Obstacle.inBarrier
			obstacle.addParticleSystem(obstacleReadyToShootParticleSystem)
		} else if obstacle.name == Obstacle.shotFromPlayer1 && obstacle.presentation.position.z > 0 {
			obstacle.name = Obstacle.readyToBeExploded // player can explode the obstacle
			obstacle.removeParticleSystem(obstacleParticleSystem)
			obstacle.addParticleSystem(obstacleReadyToExplodeParticleSystem)
		} else if obstacle.name == Obstacle.shotFromPlayer2 && obstacle.presentation.position.z < 0 {
			obstacle.name = Obstacle.readyToBeExploded // player can explode the obstacle
			obstacle.removeParticleSystem(obstacleParticleSystem)
			obstacle.addParticleSystem(obstacleReadyToExplodeParticleSystem)
		}
	}
	
	
	func shotTheObstacle(atVelocity velocity: SCNVector3) {
		for obstacle in obstacleArray {
			if obstacle.name == Obstacle.beingShotFromPlayer1 {
				obstacle.removeParticleSystem(obstacleReadyToShootParticleSystem)
				obstacle.addParticleSystem(obstacleParticleSystem)
				obstacle.physicsBody?.applyForce(velocity, asImpulse: true)
				obstacle.name = Obstacle.shotFromPlayer1
			} else if obstacle.name == Obstacle.beingShotFromPlayer2 {
				obstacle.removeParticleSystem(obstacleReadyToShootParticleSystem)
				obstacle.addParticleSystem(obstacleParticleSystem)
				obstacle.physicsBody?.applyForce(velocity, asImpulse: true)
				obstacle.name = Obstacle.shotFromPlayer2
			}
		}
	}
	
	func explodeObstacle(obstacle: SCNNode, speedUpType: Bool) {
		if speedUpType {
			obstacle.removeParticleSystem(speedUpObstacleParticleSystem)
		} else {
			obstacle.removeParticleSystem(obstacleReadyToShootParticleSystem)
			obstacle.removeParticleSystem(obstacleReadyToExplodeParticleSystem)
			obstacle.removeParticleSystem(obstacleParticleSystem)
		}
		let position = obstacle.presentation.position
		let translationMatrix = SCNMatrix4MakeTranslation(position.x, position.y, position.z)
		
		let particleSystem = speedUpType ? speedUpObstacleExplodeParticleSystem : obstacleExplodeParticleSystem
		
		raceScene?.addParticleSystem(particleSystem, transform: translationMatrix)
		obstacle.removeFromParentNode()
	}
	
	func explodeObstacleBig(obstacle: SCNNode) {
		let position = obstacle.presentation.position
		let translationMatrix = SCNMatrix4MakeTranslation(position.x, position.y, position.z)
		obstacle.removeParticleSystem(obstacleParticleSystem)
		obstacle.removeParticleSystem(obstacleReadyToShootParticleSystem)
		obstacle.removeParticleSystem(obstacleReadyToExplodeParticleSystem)
		
		raceScene?.addParticleSystem(obstacleExplodeBigParticleSystem, transform: translationMatrix)
		playSound(node: car1Node, name: "explosion")
		obstacle.removeFromParentNode()
	}
	
	func removeAllObstacles() {
		playSound(node: mainCamera, name: "explosion")
		for obstacle in obstacleArray {
			explodeObstacle(obstacle: obstacle, speedUpType: false) //also removes it
		}
		
		for speedUpObstacle in speedUpObstacleArray {
			explodeObstacle(obstacle: speedUpObstacle, speedUpType: true)
		}
	}
	
	//Cars:
	
	func calculateVelocity(point1: CGPoint, point2: CGPoint) -> SCNVector3 {
		let deltaY = Float(point2.y - point1.y)
		let deltaX = Float(point2.x - point1.x)

		let magnitude = sqrt(deltaY*deltaY + deltaX*deltaX)
		let xComponent = deltaX / magnitude * obstacleVelocity
		let zComponent = deltaY / magnitude * obstacleVelocity

		return SCNVector3(xComponent, 0, zComponent)
	}
	
	func startTheCar() {
		
		let brrrm = SCNAction.run({_ in
			//play brrmm sound (ko se vgžuje avto)
		})
		
		let driveCars = SCNAction.run({_ in
			self.car1Node?.physicsBody?.velocity = SCNVector3(self.carVelocityMagnitude, 0, 0)
			self.car2Node?.physicsBody?.velocity = SCNVector3(self.carVelocityMagnitude, 0, 0)
		})
		
		let addSmoke = SCNAction.run({_ in
			for smokeEmitter in self.smokeEmitterArray {
				smokeEmitter.addParticleSystem(self.carSmokeParticleSystem)
			}
		})

		
		car1Node?.runAction(SCNAction.sequence([brrrm, driveCars, addSmoke]))
		
	}
	
	func stopTheCars() {
		carsRemoveSmokeEffect()
		
		car1Node?.physicsBody?.velocity = SCNVector3Zero
		car1Node?.position = player1StartingPosition
		
		car2Node?.physicsBody?.velocity = SCNVector3Zero
		car2Node?.position = player2StartingPosition
	}
	
	func carsRemoveSmokeEffect() {
		for smokeEmitter in smokeEmitterArray {
			smokeEmitter.removeParticleSystem(carSmokeParticleSystem)
		}
	}
	
	//Sounds:
	
	func setupSounds() {
		loadSound("pop", fileNamed: "art.scnassets/Sounds/pop.wav")
		loadSound("explosion", fileNamed: "art.scnassets/Sounds/Explosion.wav")
		loadSound("cheer", fileNamed: "art.scnassets/Sounds/cheer.wav")
		loadSound("applause", fileNamed: "art.scnassets/Sounds/applause.wav")
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
		if gameState == .play {
			let touchLocation = touches.first?.location(in: scnView)
			for result in scnView.hitTest(touchLocation!, options: nil) {
				let nodesName = result.node.name
				
				if nodesName == Obstacle.inBarrier {
					lastTouchedLocation = touchLocation!
					if result.node.presentation.position.z < 0 { result.node.name = Obstacle.beingShotFromPlayer1 }
					else { result.node.name = Obstacle.beingShotFromPlayer2 }
					
					readyToShoot = true
				} else if nodesName == Obstacle.readyToBeExploded {
					explodeObstacle(obstacle: result.node, speedUpType: false)
				} else if controllersArray.contains(result.node) {
					result.node.opacity = 0.1
					touched(controller: result.node)
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
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		if gameState == .play {
			let touchLocation = touches.first?.location(in: scnView)
			for result in scnView.hitTest(touchLocation!, options: nil) {
				if controllersArray.contains(result.node) {
					result.node.opacity = 1.0
				}
			}
		}
	}
	
	//Scene Renderer:
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		if gameState == .play {
			updateNodesPositions()
			
			for car in [car1Node, car2Node] {
				if (car?.presentation.position.x)! > 0 && (car?.physicsBody?.velocity.x)! < 0.01 { gameOver(carWon: car!, atFinishLine: false) }
			}
		}
	}
	
	func updateNodesPositions() {
		let player1X = (car1Node?.presentation.position.x)!
		let player2X = (car2Node?.presentation.position.x)!
		let slowestCarX = player1X < player2X ? player1X : player2X
		//let fastestCarX = player1X > player2X ? player1X : player2X
		//let carDeltaX = fastestCarX - slowestCarX
		mainCamera?.position.x = slowestCarX + 16.0
		
		
		barrier1?.position = SCNVector3(x: player1X + 1, y: 0, z: (car1Node?.presentation.position.z)!)
		barrier2?.position = SCNVector3(x: player2X + 1, y: 0, z: (car2Node?.presentation.position.z)!)
		
		
		for controller in controllersArray {
			controller.position.x = (mainCamera?.position.x)! - 18.0
		}
	}
	
	//Physics Contact:
	
	func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
		if gameState == .play {
			let nodeMaskA = contact.nodeA.physicsBody?.categoryBitMask
			let nodeMaskB = contact.nodeB.physicsBody?.categoryBitMask
			
			
			if nodeMaskA == PhysicsCategory.car {
				if nodeMaskB == PhysicsCategory.obstacle || nodeMaskB == PhysicsCategory.speedUpObstacle { obstacleCollidedWithCar(car: contact.nodeA, obstacle: contact.nodeB) }
				else if nodeMaskB == PhysicsCategory.finishLine { gameOver(carWon: contact.nodeA, atFinishLine: true) }
			} else if nodeMaskB == PhysicsCategory.car {
				if nodeMaskA == PhysicsCategory.obstacle || nodeMaskA == PhysicsCategory.speedUpObstacle { obstacleCollidedWithCar(car: contact.nodeB, obstacle: contact.nodeA) }
				else if nodeMaskA == PhysicsCategory.finishLine { gameOver(carWon: contact.nodeB, atFinishLine: true) }
				
			} else if nodeMaskA == PhysicsCategory.barrier {
				obstacleInBarrier(barrier: contact.nodeA, obstacle: contact.nodeB)
			} else if nodeMaskB == PhysicsCategory.barrier {
					obstacleInBarrier(barrier: contact.nodeB, obstacle: contact.nodeA)
			
			} else if nodeMaskA == PhysicsCategory.borderLine { explodeObstacle(obstacle: contact.nodeB, speedUpType: false) }
			else if nodeMaskB == PhysicsCategory.borderLine { explodeObstacle(obstacle: contact.nodeA, speedUpType: false) }
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
