/*############################################################################*/
// Typed-Array-Json (https://github.com/mgreter/typed-json.js)
// - Copyright (c) 2017 Marcel Greter (http://github.com/mgreter)
/*############################################################################*/
'use strict';

(function (exports)
{

	// format specific headers
	var headers = [
		// values are always stored in little-endian byte-order
		[Float64Array /*, 8, "float64" */], // double precision float
		[Float32Array /*, 8, "float32" */], // single precision float
		[Uint32Array /*, 4, "uint32" */], // unsigned long
		[Int32Array /*, 4, "int32" */], // signed long
		[Uint16Array /*, 2, "uint16" */], // unsigned short
		[Int16Array /*, 2, "int16" */], // signed short
		[Uint8Array /*, 1, "uint8" */], // unsigned char
		[Int8Array /*, 1, "int8" */], // signed char
	];

	// create final json from data and buffer
	function TypedJson(data, buffer, offset)
	{

		// additional offset
		offset = offset || 0;

		// base assertions for valid inputs
		if (!data || !buffer || !data.maps || !data.json) {
			throw "Invalid TypedJson arguments";
		}

		// only map the arrays once (idempotent)
		// ToDo: what if buffer or offset changed?
		// ToDo: should we error in that case
		if (data.maps === true) return data.json;

		// get main data items
		var maps = data.maps;
		var json = data.json;

		// check if file is big enough
		// or we may get generic errors
		if (buffer.byteLength < 40) {
			throw "Buffer to short for jdbd";
		}
		// first read the header values
		var header = new Uint32Array(buffer, offset, 3);
		// check the static header prefix
		if (header[0] != 1650745962 || header[1] != 0) {
			throw "Invalid buffer prefix (or version)";
		}
		// check that loaded size matches
		if (header[2] > buffer.byteLength - offset) {
			throw "Buffer is too small / not fully loaded";
		}

		// second create view for array counts
		var counts = new Uint32Array(buffer, offset + 12, 8);
		// sum-up all array counts
		var counter = 0, arrays = [];

		// third read in offsets and lengths
		// for that we need to know how many
		// go through the set of arrays to count
		// format has exactly 8 types
		for (var i = 0; i < 8; i++) {
			counter += counts[i];
		}

		// fourth create view for array metadata
		// has an offset and a length for every array
		var meta = new Uint32Array(buffer, offset + 44, counter * 2);

		// fifth create the real arrays
		var base = 44 + counter * 2 * 4;
		for (var i = 0, off = 0; i < 8; i++) {
			var arrayCtor = headers[i][0];
			for (var n = 0; n < counts[i]; n++) {
				var addr = offset + base + meta[off++];
				arrays.push(new arrayCtor(buffer, addr, meta[off++]));
			}
		}

		// sixth replace mappings
		// creates final json object
		for (var map in maps) {
			var object = json;
			if (map == "") continue;
			var parts = map.split(/\./);
			while (parts.length > 1) {
				var part = parts.shift();
				object = object[part];
			}
			// add array to given json key
			object[parts[0]] = arrays[maps[map]];
		}

		// mark object as "processed"
		// also releases some memory
		data.maps = true;

		// convenience
		return json;

	}
	// EO TypedJson

	// export into parent namespace
	exports.TypedJson = TypedJson;

})(this);
