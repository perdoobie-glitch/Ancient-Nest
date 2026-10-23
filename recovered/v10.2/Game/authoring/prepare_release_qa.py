"""Build a separate release QA project; never modifies the playable project.
Usage: python authoring/prepare_release_qa.py /absolute/path/to/new-qa-folder
"""
from pathlib import Path
import sys,shutil
source=Path(__file__).resolve().parent.parent
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else source.parent/'AncientNest-QA'
if root==source or root.exists():raise SystemExit('Choose a new, empty QA output folder.')
shutil.copytree(source,root,ignore=shutil.ignore_patterns('.godot','.git','authoring','output'))
for name,original in [('production_server_probe','network_production_server'),('polish_probe','polish_benchmark'),('intro_probe','intro_update'),('nest_forge_probe','nest_forge_v34'),('matchmaking_probe','matchmaking_v35'),('matchmaking_network_probe','network_matchmaking_v35'),('matchmaking_audio_probe','matchmaking_audio_cleanup')]:
 s=(source/'tests'/f'{original}.gd').read_text().replace('extends SceneTree','extends Node',1)
 s=s.replace('func _initialize():call_deferred("run")','var root: Window\nvar current_scene: Node:\n get:return get_tree().current_scene\n set(value):get_tree().current_scene=value\nfunc _ready():\n root=get_tree().root\n call_deferred("run")')
 s=s.replace('res://tests/matchmaking_hold_ack.gd','res://scripts/matchmaking_hold_ack.gd').replace('res://tests/matchmaking_ignore_registration.gd','res://scripts/matchmaking_ignore_registration.gd')
 s=s.replace('await process_frame','await get_tree().process_frame').replace('await physics_frame','await get_tree().physics_frame').replace('create_timer(','get_tree().create_timer(').replace('quit(','get_tree().quit(')
 if original=="intro_update":s=s.replace('check(ProjectSettings.get_setting("application/run/main_scene")=="res://intro/intro_scene.tscn","Launch scene owns startup artwork followed by creator intro")','check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/qa_release.tscn" and ResourceLoader.exists("res://intro/intro_scene.tscn"),"QA launcher includes and exercises the shipped startup intro")')
 (root/'scripts'/f'{name}.gd').write_text(s)
for fixture in ['matchmaking_hold_ack.gd','matchmaking_ignore_registration.gd']:
 shutil.copy2(source/'tests'/fixture,root/'scripts'/fixture)
(root/'scripts/qa_release.gd').write_text('extends Node\nfunc _ready():\n var path="res://scripts/production_server_probe.gd" if "--qa-production-server" in OS.get_cmdline_user_args() else "res://scripts/matchmaking_audio_probe.gd" if "--qa-matchmaking-audio" in OS.get_cmdline_user_args() else "res://scripts/matchmaking_network_probe.gd" if "--qa-matchmaking-network" in OS.get_cmdline_user_args() else "res://scripts/matchmaking_probe.gd" if "--qa-matchmaking" in OS.get_cmdline_user_args() else "res://scripts/nest_forge_probe.gd" if "--qa-nest-forge" in OS.get_cmdline_user_args() else "res://scripts/intro_probe.gd" if "--qa-intro" in OS.get_cmdline_user_args() else "res://scripts/polish_probe.gd"\n add_child(load(path).new())\n')
(root/'scenes/qa_release.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/qa_release.gd" id="1"]\n[node name="ReleaseQA" type="Node"]\nscript=ExtResource("1")\n')
p=root/'project.godot';s=p.read_text().replace('run/main_scene="res://intro/intro_scene.tscn"','run/main_scene="res://scenes/qa_release.tscn"');p.write_text(s)
