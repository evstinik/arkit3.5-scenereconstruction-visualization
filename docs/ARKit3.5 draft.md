## Intro

At SABO we do many interesting projects. 

We work with such companies as Audi and [NavVis](https://www.navvis.com/). 

One of the projects we work with Audi on is an iOS app based on ARKit. It's NDA protected, but so that you get general idea short description follows. We fetch the information about real objects *(future/planned)* locations and render them in augmented reality as much precisely positioned as ARKit allows us.

We've encountered multiple technical challenges on the way, most of which were more or less related to the positioning. Considerable inaccuracy of ARKit *(is/was)* the biggest ~~*pain in the ass*~~ issue, that took us many hours of research and experiments to solve.

This was our motivation to try new iPad Pro with LiDAR and ARKit 3.5.

We were keen on what kind of data can ARKit provide us and what exactly has changed since last version. That's what I want to share with you.

## Theoretical part (TODO: rename)

### Anchors

ARKit solves mapping virtual objects to real-world surfaces via anchors. Every anchor carries information about it's *transform* (position, orientation, scale) in virtual 3D world space. By using this information we are able to render our entities at well fitting position/orientation/scale. So that when it's rendered over video stream coming from camera it looks like it's really there.

First version only allowed developers to put objects on horizontal planes. Step by step API was extended and now (in last major release at date of writing is ARKit 3) we have 4 types of anchors: `ARPlaneAnchor` (vertical and horizontal planes), `ARImageAnchor` (pre-trained image), `ARObjectAnchor` (pre-trained 3D object ) and `ARFaceAnchor` (human's face).

ARKit 3.5 introduced a new type of anchor - `ARMeshAnchor`. As you may already got from it's name, `ARMeshAnchor` not only provides transform. By collecting data from LiDAR, it also provides information about *geometry of surroundings*.

### Raw data 

Accessing geometry provided by [`ARMeshAnchor`](https://developer.apple.com/documentation/arkit/armeshgeometry) is done via `var geometry: ARMeshGeometry { get }` property.

Let's now look more closely at new structure `ARMeshGeometry`(https://developer.apple.com/documentation/arkit/armeshgeometry):
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

Vertices, normals and classification are represented with new class [`ARGeometrySource`](https://developer.apple.com/documentation/arkit/argeometrysource). *Mesh data in a buffer-based array* says Apple documentation. Type of data represented in `buffer` is described by [`MTLVertexFormat`](https://developer.apple.com/documentation/metal/mtlvertexformat).

So `ARGeometrySource` points to piece of `MTLBuffer`, which is an array of vectors with `count` elements. Vector itself is also an array with fixed length (`stride` bytes), described in `format`.

Experimentally I found out, that for vertices and normals format is `MTLVertexFormat.float3`, i.e. 3 floats representing X, Y and Z coordinate of vertex / vector respectively.

**TODO: Add format for classification**

What also I found out is that amount of normals is the same as amount of *vertices*, not faces. This fact neither match documentation, which describes normals property as *rays that define which direction is outside for each face.*, nor it fits the general meaning of a normal.

Next data type is [`ARGeometryElement`](https://developer.apple.com/documentation/arkit/argeometryelement), which is used for faces description. It also contains a Metal `buffer: MTLVertexFormat`. Buffer contains an array of array of vertex indices. Each element in buffer represent face. Face is represented by fixed amount of numbers (`indexCountPerPrimitive`). Each number is a vertex index.

## Practical part (TODO: rename)

What I found interesting to explore is how does ARKit assign `ARMeshAnchor` to the feature points. RealityKit provides a visualisation for debugging purposes, but it only shows grid based on geometries of *all* anchors. It's not possible to say how does single anchor's geometry look like.

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

And here is the result:

![Mesh split visualisation](https://github.com/evstinik/arkit3.5-scenereconstruction-visualization/blob/master/docs/RPReplay_Final1590411087_downsized_trimed.gif?raw=true](https://github.com/evstinik/arkit3.5-scenereconstruction-visualization/blob/master/docs/RPReplay_Final1590411087_downsized_trimed.gif?raw=true))

As we can see the ARKit produces "square" meshes 1m x 1m approximately. Some of them may overlap with each other. 

## Conclusion

TODO 
