class_name NestNetworkCleanup
extends RefCounted
## Godot 4.6.3 SceneCacheInterface.clear() disconnects an unbound callable,
## although _track() connected it with the node ID bound. Release templates
## consequently leave tree_exited hooks behind across peer replacement.
## Retire only that exact native cache entry and its matching bound hook.
## Reference: godotengine/godot 4.6.3-stable modules/multiplayer/scene_cache_interface.cpp
static func retire_rpc_cache(nodes: Array) -> int:
 var version=Engine.get_version_info()
 if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3:return 0
 var retired=0
 for node in nodes:
  if not is_instance_valid(node):continue
  for connection in node.get_signal_connection_list("tree_exited"):
   var callback: Callable=connection.callable
   var owner=callback.get_object()
   if owner==null or owner.get_class()!="SceneCacheInterface" or not callback.is_valid():continue
   var bound=callback.get_bound_arguments()
   if bound.size()!=1 or bound[0]!=node.get_instance_id() or (int(connection.flags)&Object.CONNECT_ONE_SHOT)==0:continue
   # Same bookkeeping as a real node exit, while this transport still exists.
   callback.call()
   if node.is_connected("tree_exited",callback):node.disconnect("tree_exited",callback)
   retired+=1
 return retired
