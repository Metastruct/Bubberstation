/// Recursively copies a (possibly associative, possibly nested) list, leaving
/// non-list values (scalars, typepaths, datum refs) untouched.
/proc/deep_copy_nested_list(list/inserted_list)
	if(!islist(inserted_list))
		return inserted_list
	var/list/copied = inserted_list.Copy()
	for(var/key, value in inserted_list)
		if(islist(value))
			copied[key] = deep_copy_nested_list(value)
	return copied
