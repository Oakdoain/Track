extends RefCounted
class_name JsonVariantNormalizer


static func normalize(value: Variant, path: String = "root") -> Dictionary:
	if value == null or value is bool or value is String:
		return _success(value)
	if value is StringName:
		return _success(str(value))
	if value is int:
		return _success(value)
	if value is float:
		var number := float(value)
		if is_nan(number) or is_inf(number):
			return _failure(path, "finite number", value, "non-finite numbers cannot be encoded as JSON")
		return _success(number)
	if value is Array:
		var normalized_array: Array = []
		for index in range((value as Array).size()):
			var item_result := normalize((value as Array)[index], "%s[%d]" % [path, index])
			if not bool(item_result.get("success", false)):
				return item_result
			normalized_array.append(item_result.get("value"))
		return _success(normalized_array)
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			if not (key_value is String) and not (key_value is StringName):
				return _failure(path, "Dictionary with String keys", key_value, "dictionary key is not a String")
			var key := str(key_value)
			var item_result := normalize((value as Dictionary)[key_value], path + "." + key)
			if not bool(item_result.get("success", false)):
				return item_result
			normalized_dictionary[key] = item_result.get("value")
		return _success(normalized_dictionary)

	return _failure(
		path,
		"null, bool, number, String, Array, or Dictionary<String, Variant>",
		value,
		"unsupported runtime type must be converted explicitly before saving"
	)


static func _success(value: Variant) -> Dictionary:
	return {"success": true, "value": value, "error": ""}


static func _failure(path: String, expected: String, actual: Variant, reason: String) -> Dictionary:
	var actual_type := type_string(typeof(actual))
	var summary := str(actual)
	if summary.length() > 120:
		summary = summary.left(117) + "..."
	return {
		"success": false,
		"path": path,
		"expected": expected,
		"actual_type": actual_type,
		"actual_summary": summary,
		"reason": reason,
		"error": "%s: expected %s, got %s, value=%s; %s" % [
			path, expected, actual_type, summary, reason
		]
	}
