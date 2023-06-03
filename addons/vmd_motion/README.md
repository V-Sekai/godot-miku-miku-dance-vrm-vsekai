# VMDMotionGD

VMDMotionGD is a tool to play VMD (Vocaloid Motion Data) animation on Unity humanoid-style characters.

This is a Godot Engine 3.x port of [lox9973's tool](https://gitlab.com/lox9973/VMDMotion/-/tree/master).

# Usage

VMDMotionGD is designed to be used with [godot-vrm](https://github.com/V-Sekai/godot-vrm).

A specific `VMDAnimator` base will need to be implemented for the humanoid bone mapping and other things, an example VRM implementation is provided in `runtime/VRMAnimator.gd`, this will probably be split off in the future.

Create a VRM animator, put the VRMTopLevel as a child of it, then create a VMDPlayer.

# Stuff to do

- [x] Basic functionality (VMD loading)
- [ ] VMD camera loading
- [ ] Morph support & VRM morph support framework
- [ ] C++ port (If needed)
- [ ] 4.0 port (waiting for GDScript to become more stable)
