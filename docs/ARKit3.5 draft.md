At SABO we do many interesting projects. 

We work with such companies as Audi and [NavVis](https://www.navvis.com/). 

One of the projects we work with Audi on is an iOS app based on ARKit. It's NDA protected, but so that you get general idea short description follows. We fetch the information about real objects *(future/planned)* locations and render them in augmented reality as much precisely positioned as ARKit allows us.

We've encountered multiple technical challenges on the way, most of which were more or less related to the positioning. Considerable inaccuracy of ARKit *(is/was)* the biggest ~~*pain in the ass*~~ issue, that took us many hours of research and experiments to solve.

This was our motivation to try new iPad Pro with LiDAR and ARKit 3.5.

We were keen on what kind of data can ARKit provide us and what exactly has changed since last version. That's what I want to share with you.

### Anchors

ARKit solves mapping virtual objects to real-world surfaces via anchors. Every anchor carries information about it's *transform* (position, orientation, scale) in virtual 3D world space. By using this information we are able to render our entities at well fitting position/orientation/scale. So that when it's rendered over video stream coming from camera it looks like it's really there.

First version only allowed developers to put objects on horizontal planes. Step by step API was extended and now (in last major release at date of writing is ARKit 3) we have 4 types of anchors: `ARPlaneAnchor` (vertical and horizontal planes), `ARImageAnchor` (pre-trained image), `ARObjectAnchor` (pre-trained 3D object ) and `ARFaceAnchor` (human's face).

ARKit 3.5 introduced a new type of anchor - `ARMeshAnchor`. As you may already got from it's name, `ARMeshAnchor` not only provides transform. By collecting data from LiDAR, it also provides information about *geometry of surroundings*.

Many 


