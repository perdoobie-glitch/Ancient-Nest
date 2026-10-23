class_name NestGrenadeArt
extends RefCounted
static var blue: StandardMaterial3D
static var green: StandardMaterial3D
static func material(sticky: bool) -> StandardMaterial3D:
 if blue==null:
  blue=StandardMaterial3D.new();blue.albedo_color=Color("398dff");blue.emission_enabled=true;blue.emission=Color("247fff");blue.emission_energy_multiplier=3.0
  green=StandardMaterial3D.new();green.albedo_color=Color("437b35");green.roughness=.65
 return blue if sticky else green
