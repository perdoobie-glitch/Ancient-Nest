extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func token(key: CryptoKey) -> String:
 var raw=JSON.stringify({"v":1,"kind":"authority","match":"test-match","epoch":1,"subject":"player","authority":"player","issued":95,"expires":110}).to_utf8_buffer()
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
 return Marshalls.raw_to_base64(raw)+"."+Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key))
func run():
 var session=NestHybridSession.new();root.add_child(session);session.set_process(false)
 var first=Crypto.new().generate_rsa(2048);var second=Crypto.new().generate_rsa(2048)
 check(session.configure("test-match","player",first.save_to_string(true),func():return 100.0)==OK,"Initial coordinator signing key loads")
 check(not session.verify_grant(token(first),"authority",1,"player","player").is_empty(),"Initial coordinator grant verifies")
 check(session.configure("test-match","player",first.save_to_string(true),func():return 100.0)==OK,"Reconnect reloads the same key cleanly")
 check(session.configure("test-match","player",second.save_to_string(true),func():return 100.0)==OK,"New coordinator key replaces the old key")
 check(not session.verify_grant(token(second),"authority",1,"player","player").is_empty(),"Replacement key verifies its grant")
 check(session.verify_grant(token(first),"authority",1,"player","player").is_empty(),"Old signing key is no longer trusted")
 session.queue_free();await process_frame;quit(1 if failures else 0)
