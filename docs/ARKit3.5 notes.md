# ARKit 3.5

## Open questions

- How does the ARKit splits the meshes? Possibly good topic for visualisation
- How to access vertices / faces / classification?
- How to generate ModelEntity in runtime using the mesh data from LiDAR?

## Theoretical notes

### Overall changes
-   AR configuration option `sceneReconstruction` (`.meshWithClassification`, `.mesh`)
-   Raycast on mesh only when used with options `ARRaycastQuery.Target.estimatedPlane` and `ARRaycastQuery.TargetAlignment.any`
-   Mesh classification (disabled by default, as not required for occlusion or physics)
-   Classification is a demanding process, recommended to be done asynchroniously (describe how?)
-   Each three vertices in a mesh form a face, ARKit assigns classification to each face, so to determine mesh classification one of the options is to find closes face to selected point and get it’s classification

### New classes/structures
```swift
/**
A three-dimensional shape that represents the geometry of a mesh.
*/
@available(iOS 13.4, *)
open class ARMeshGeometry : NSObject, NSSecureCoding {
	
	/*
	The vertices of the mesh.
	*/
	open var vertices: ARGeometrySource { get }

	/*
	The normals of the mesh.
	*/
	open var normals: ARGeometrySource { get }

	/*
	A list of all faces in the mesh.
	*/
	open var faces: ARGeometryElement { get }

	/*
	Classification for each face in the mesh.
	*/
	open var classification: ARGeometrySource? { get }
}
```
  

Most of the properties are represented with `ARGeometrySource`, which is also a new class. “Mesh data in a buffer-based array” says Apple documentation.
```swift
/**
A container for vector data of a geometry.
*/
@available(iOS  13.4, *)
open  class  ARGeometrySource : NSObject, NSSecureCoding {
	
	/**
	A Metal buffer containing per-vector data for the source.
	*/
	open var buffer: MTLBuffer { get }

	/**
	The number of vectors in the source.
	*/
	open var count: Int { get }

	/**
	The type of per-vector data in the buffer.
	*/
	open  var  format: MTLVertexFormat { get }

	/**
	The number of scalar components in each vector.
	*/
	open  var  componentsPerVector: Int { get }

	/**
	The offset (in bytes) from the beginning of the buffer.
	*/
	open var offset: Int { get }

	/**
	The number of bytes from a vector to the next one in the buffer.
	*/
	open var stride: Int { get }
}
```
So the type of data represented in `buffer` is described by [`MTLVertexFormat`](https://developer.apple.com/documentation/metal/mtlvertexformat).

So `ARGeometrySource` points to piece of `MTLBuffer`, which is an array of vectors with `count` elements. Vector itself is also an array with fixed length (`stride` bytes), described in `format`.

- For vertices format is `MTLVertexFormat.float3`, i.e. 3 floats representing X, Y and Z coordinate of vertex.
- For normals format is `MTLVertexFormat.float3`, i.e. 3 floats representing X, Y and Z coordinate of vector. Normal additionally describes a vertex (it's orientation), not the face, so the count of normals is the same as count of **vertices** (PLEASE CHECK IF IT'S GIVING SENSE, DOCUMENTATION SAYS IT'S 1:1 TO FACE)

Next data type is [`ARGeometryElement`](https://developer.apple.com/documentation/arkit/argeometryelement), which is used for faces description. It also contains a Metal `buffer: MTLVertexFormat`. Buffer contains an array of array of vertex indices. Each element in buffer represent face. Face is represented by fixed amount of numbers (`indexCountPerPrimitive`). Each number is a vertex index.

## Working with mesh

### Procedural meshes

Generating and presenting a virtual object based on mesh data from LiDAR in real-time can be very cool, can't it?

Unfortunately, procedural meshes in RealityKit are still [not fully supported](https://forums.developer.apple.com/thread/117823). You definitely [can](https://developer.apple.com/documentation/realitykit/creating_3d_content_with_reality_composer/adding_procedural_assets_to_a_scene) generate primitives by using `MeshSource.generateBox` and similar, but not complex mesh. Geometry provided in `ARMeshAnchor` is a set of faces and you won't be able to represent it using primitives.  Not a surprise that RealityKit is still quite new and is on it's path to matureness.

There is still one way in RealityKit though. You [can](https://github.com/zeitraumdev/iPadLIDARScanExport/blob/master/iPadLIDARScanExport/ViewController.swift#L117) generate a MDLAsset via [Model I/O](https://developer.apple.com/documentation/modelio) framework, [export](https://github.com/zeitraumdev/iPadLIDARScanExport/blob/master/iPadLIDARScanExport/ViewController.swift#L181) it to usdz format and import again into RealityKit via [`ModelEntity.load(contentsOf:withName:)`](https://developer.apple.com/documentation/realitykit/modelentity/3244477-load). But you may experience high latency in real-time use case due to I/O operations with file system.

Where I really did succeed in runtime mesh generation is SceneKit. SceneKit allows you to dynamically create `SCNGeometry` and assign it to `SCNNode`. 

With a few handy extensions the code can look like this:
```swift
// MARK: **- ARSCNViewDelegate**

func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
	// Create a node for a new ARMeshAnchor
	// We are only interested in anchors that provide mesh
	guard let meshAnchor = anchor as? ARMeshAnchor else {
		return nil
	}
	// Generate a SCNGeometry (explained further)
	let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)
	// Let's assign random color to each ARMeshAnchor/SCNNode be able to distinguish them in demo
	geometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
	// Create node & assign geometry
	let node = SCNNode()
	node.name = "DynamicNode-\(meshAnchor.identifier)"
	node.geometry = geometry
	return node
}

func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
	// Update the node's geometry when mesh or position changes
	guard let meshAnchor = anchor as? ARMeshAnchor else {
		return
	}
	// Generate a new geometry
	let newGeometry = SCNGeometry(arGeometry: meshAnchor.geometry)  // regenerate geometry
	// Assign the same color (colorizer stores id <-> color map internally)
	newGeometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
	// Replace node's geometry with a new one
	node.geometry = newGeometry
}
```

Conversion of `ARMeshGeometry` to `SCNGeometry` is pretty straightforward as structures are very similar:
```swift
extension  SCNGeometry {
	convenience init(arGeometry: ARMeshGeometry) {
		let verticesSource = SCNGeometrySource(arGeometry.vertices, semantic: .vertex)
		let normalsSource = SCNGeometrySource(arGeometry.normals, semantic: .normal)
		let faces = SCNGeometryElement(arGeometry.faces)
		self.init(sources: [verticesSource, normalsSource], elements: [faces])
	}
}

extension  SCNGeometrySource {
	convenience init(_ source: ARGeometrySource, semantic: Semantic) {
		self.init(buffer: source.buffer, vertexFormat: source.format, semantic: semantic, vertexCount: source.count, dataOffset: source.offset, dataStride: source.stride)
	}
}

extension  SCNGeometryElement {
	convenience init(_ source: ARGeometryElement) {
		let pointer = source.buffer.contents()
		let byteCount = source.count * source.indexCountPerPrimitive * source.bytesPerIndex
		let data = Data(bytesNoCopy: pointer, count: byteCount, deallocator: .none)
		self.init(data: data, primitiveType: .of(source.primitiveType), primitiveCount: source.count, bytesPerIndex: source.bytesPerIndex)
	}
}

extension  SCNGeometryPrimitiveType {
	static  func  of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
		switch type {
		case .line:
			return .line
		case .triangle:
			return .triangles
		}
	}
}
```

Results
![Mesh split visualisation](https://github.com/evstinik/arkit3.5-scenereconstruction-visualization/blob/master/docs/RPReplay_Final1590411087_downsized_trimed.gif?raw=true](https://github.com/evstinik/arkit3.5-scenereconstruction-visualization/blob/master/docs/RPReplay_Final1590411087_downsized_trimed.gif?raw=true))

As we can see the ARKit produces "square" meshes 1m x 1m approximately. Some of them may overlap each other. 

### Classification visualisation

- How to apply texture
	- "image paste" UV mapping
	- calculating bounding box
	- texcoords geometry source
- Generate geometry from faces with given classification

Result
![Classification visualisation](https://github.com/evstinik/arkit3.5-scenereconstruction-visualization/blob/master/docs/RPReplay_Final1590577789downsized_trimed.gif?raw=true))

## Hands-on notes
Enabling:
```swift
arView.automaticallyConfigureSession = false

let configuration = ARWorldTrackingConfiguration()

configuration.sceneReconstruction = .meshWithClassification
```
Debugging:
```swift
arView.debugOptions.insert(.showSceneUnderstanding)
```
Accessing vertices:
1. Getting an `ARMeshAnchor`
	```swift
	// 1. Get the ARSession instance
	// a) in RealityKit with `arView: ARView`
	let session = arView.session
	// b) ARKit with `sceneView: ARSCNView`
	let session = sceneView.session
	// 2. Get all anchors in current frame
	guard let frame = session.currentFrame else { return }
	let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
	```
2. Iterating the vertices:
	```swift
	let vertices = meshAnchor.geometry.vertices
	// Expected format of vertices is float3
	guard vertices.format == MTLVertexFormat.float3 else { return }
	for vertexIndex in 0..<vertices.count {
		let vertexOffset = vertices.offset + (vertices.stride * Int(vertexIndex))
		let vertexPointer = vertices.buffer.contents().advanced(by: vertexOffset)
		let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
		// Your code here to process vertex, tuple (Float, Float, Float)
	}
	```
TODO: Accessing faces, normals.

## Ideas

- Position diffing of object laying on floor
- Visualise normals
- Detecting object 3d position by raycasting center of 2d bounding box returned by Vision framework

## References
-   [https://developer.apple.com/documentation/arkit/world_tracking/visualizing_and_interacting_with_a_reconstructed_scene](https://developer.apple.com/documentation/arkit/world_tracking/visualizing_and_interacting_with_a_reconstructed_scene)

	Notes:
	- 4th generation of iPad Pro, iPad OS 13.4 or later
	- polygonal model of physical environment
	- more accurately locate points on real-world surfaces
	- classify real-world objects
	- interaction with real-world objects

-   [https://stackoverflow.com/questions/61063571/arkit-3-5-how-to-export-obj-from-new-ipad-pro-with-lidar](https://stackoverflow.com/questions/61063571/arkit-3-5-how-to-export-obj-from-new-ipad-pro-with-lidar)
-   [https://structure.io/](https://structure.io/)
-   [https://medium.com/zeitraumgruppe/what-arkit-3-5-and-the-new-ipad-pro-bring-to-the-table-d4bf25e5dd87](https://medium.com/zeitraumgruppe/what-arkit-3-5-and-the-new-ipad-pro-bring-to-the-table-d4bf25e5dd87)
