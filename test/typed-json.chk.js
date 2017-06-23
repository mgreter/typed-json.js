(function (exports)
{

	// implement our own deep compare
	// easier to hunt down test failures
	function compareDeep(o, p, paths)
	{

		var path = null;
		paths = paths || [];

		if (o === null) {
			if (p !== null) {
				console.log('One is null, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
		}
		else if (o === undefined) {
			if (p !== undefined) {
				console.log('One is undefined, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
		}
		else if (o instanceof Array) {
			if (!(p instanceof Array)) {
				console.log('One is Array, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			if (o.length !== p.length) {
				console.log('Number of items mismatch');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			for (var i = 0; i < o.length; i++) {
				paths.push(path = i)
				if (!compareDeep(o[i], p[i], paths)) {
					// console.log('Child compare failed');
					return false;
				}
				paths.pop();
			}
		}
		else if (o instanceof Object) {
			if (!(p instanceof Object)) {
				console.log('One is Object, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			var keysO = Object.keys(o);
			var keysP = Object.keys(p);
			if (keysO.length !== keysP.length) {
				console.log('Number of keys mismatch');
				console.log('At', paths.join('.'))
				console.log(o, p);
				return false;
			}
			keysO.sort();
			keysP.sort();
			if (keysO.join('') != keysP.join('')) {
				console.log('Keys are not the same');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			for (var i = 0; i < keysO.length; i++) {
				paths.push(path = keysO[i])
				if (!compareDeep(o[path], p[path], paths)) {
					// console.log('Child compare failed');
					return false;
				}
				paths.pop(i)
			}
		}
		else if (!isNaN(o)) {
			if (isNaN(p)) {
				console.log('One seems a number, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			// this check should only fix comparison
			// between TypedArrays and regular values
			if (1.0 - Math.abs(o / p) > 1e-7) {
				console.log('Numbers are not equal')
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
		}
		else if (o.hasOwnProperty('length')) {
			if (!p.hasOwnProperty('length')) {
				console.log('One has length, the other not');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			if (o.length !== p.length) {
				console.log('Lengths are not the same');
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
			if (o != p) {
				console.log('Strings are not equal')
				console.log('At', paths.join('.'))
				console.log(o, "vs", p);
				return false;
			}
		}
		else if (o != p) {
			console.log('Values are not equal')
			console.log('At', paths.join('.'))
			console.log(o, "vs", p);
			return false;
		}

		return true;

	}
	// EO compareDeep

	// execute tests on one set of files
	function executeTest(test, assert)
	{

		// need to load two files
		// just hard-code it here
		// poor man's promise :)
		var data, buffer, orig;
		var done = assert.async();

		// create closure scope
		var startTest = function ()
		{

			// just create the binary database
			var json = TypedJson(data, buffer);
			assert.ok(compareDeep(json, orig), test);
			setTimeout(done, test == 'iss' ? 10 : 0);
		}

		// fetch original json to compare
		var origUrl = "data/" + test + ".json";
		var xmlhttpOrig = new XMLHttpRequest();
		xmlhttpOrig.onreadystatechange = function ()
		{
			if (this.readyState == 4) {
				if (this.status == 200) {
					orig = this.response;
					if (buffer && data) startTest();
				} else {
					throw "Failed to load " + origUrl;
				}
			}
		};
		xmlhttpOrig.responseType = "json";
		xmlhttpOrig.open("GET", origUrl, true);
		xmlhttpOrig.send();

		// fetch json with buffer mappings
		var dataUrl = "data/" + test + ".jdb";
		var xmlhttpData = new XMLHttpRequest();
		xmlhttpData.onreadystatechange = function ()
		{
			if (this.readyState == 4) {
				if (this.status == 200) {
					data = this.response;
					if (buffer && orig) startTest();
				} else {
					throw "Failed to load " + dataUrl;
				}
			}
		};
		xmlhttpData.responseType = "json";
		xmlhttpData.open("GET", dataUrl, true);
		xmlhttpData.send();

		// fetch binary buffers for mappings
		var dbUrl = "data/" + test + ".jbdb";
		var xmlhttpDb = new XMLHttpRequest();
		xmlhttpDb.onreadystatechange = function ()
		{
			if (this.readyState == 4) {
				if (this.status == 200) {
					buffer = this.response;
					if (data && orig) startTest();
				} else {
					throw "Failed to load " + dbUrl;
				}
			}
		};
		xmlhttpDb.responseType = "arraybuffer";
		xmlhttpDb.open("GET", dbUrl, true);
		xmlhttpDb.send();

	}
	// EO executeTest

	// define a new test module
	QUnit.module('Typed Array Json', function ()
	{
		QUnit.test('Deep Object Compare', function (assert)
		{
			executeTest('types', assert);
			executeTest('iss', assert);
		});
	});

})(this);