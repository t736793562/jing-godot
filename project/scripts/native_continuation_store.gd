extends "res://scripts/native_save.gd"
# Revision 1 stays unchanged. Revision 2 must reproduce its full typed state from
# a valid D11-morning revision-1 anchor and a bounded whitelist of native actions.
const Journal=preload("res://scripts/native_continuation.gd")
const ReplayModel=preload("res://scripts/game_model.gd")
var replay_engine=ReplayModel.new()
var active_proof: Dictionary={}
var decoded_proof: Dictionary={}
func encode(state: Dictionary) -> String:
	error="";nodes=0
	if active_proof.is_empty():return super.encode(state)
	var replayed: Dictionary=Journal.replay(active_proof,replay_engine)
	if not replayed.ok or not replay_engine.p1_validate_state() or not replay_engine.route_validate() or not replay_engine.disclosure_validate() or var_to_bytes(replayed.state)!=var_to_bytes(state):error="CONTINUATION_MISMATCH";return ""
	var tagged=encode_value({"state":state,"proof":active_proof})
	if not error.is_empty():return ""
	var payload:=JSON.stringify(tagged)
	var result:=JSON.stringify({"format":FORMAT,"revision":2,"payload":payload,"sha256":payload.sha256_text()})
	if result.to_utf8_buffer().size()>MAX_BYTES:error="SIZE";return ""
	return result
func decode(text: String) -> Dictionary:
	error="";nodes=0;decoded_proof={}
	if text.to_utf8_buffer().size()>MAX_BYTES:error="SIZE";return {}
	var parser:=JSON.new()
	if parser.parse(text)!=OK:error="JSON";return {}
	var envelope=parser.data
	if envelope is Dictionary and envelope.get("revision")==1:return super.decode(text)
	if not envelope is Dictionary or envelope.size()!=4 or envelope.get("format")!=FORMAT or envelope.get("revision")!=2 or not envelope.get("payload") is String or not envelope.get("sha256") is String:error="ENVELOPE";return {}
	if envelope.payload.sha256_text()!=envelope.sha256:error="CHECKSUM";return {}
	if parser.parse(envelope.payload)!=OK:error="PAYLOAD_JSON";return {}
	var value=decode_value(parser.data)
	if not error.is_empty():return {}
	if not value is Dictionary or value.size()!=2 or not value.get("state") is Dictionary or not value.get("proof") is Dictionary:error="CONTINUATION_PAYLOAD";return {}
	var replayed: Dictionary=Journal.replay(value.proof,replay_engine)
	if not replayed.ok or not replay_engine.p1_validate_state() or not replay_engine.route_validate() or not replay_engine.disclosure_validate() or var_to_bytes(replayed.state)!=var_to_bytes(value.state):error="CONTINUATION_MISMATCH";return {}
	decoded_proof=value.proof.duplicate(true);return value.state
