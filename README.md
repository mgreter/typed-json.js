# Typed Array JSON

JSON with Typed Arrays mixed in. Useful when you have
JSON data with a lot of numerical-only arrays.

It is only intended to be used to import this kind of
JSON data. It probably only makes sense if your JSON is
over 100kb anyway. It is most useful if you can use the
Typed Arrays directly (i.e. to pass to WebGL or WebWorkers).

The main use is to optimize ThreeJS JSON models, where we
have multiple numeric arrays that will be passed to WebGL.

## Preparing Data Files

In order to use this library, you need to create two specific
files from any valid JSON file (see test/data folder). This
includes an altered JSON (with mapping info) and the main
array buffer (with header and metadata). This repository
includes a perl script to generate these files from any JSON.

```cmd
perl typed-json.pl [-c] input{.json} [output{.jdb}]
```

The cli tool is very simplistic and also works with Strawberry
Perl on windows. It only handles the most common cases and
lacks more options and better error handling. But it gets the
job done! A node.js implementation would be nice :)

It supports an optional compress options, which will need [`lzma`][2]
(the one from 7-zip) in your global path. This works nicely together
with [`js-lzma`][3] to further reduce file-size. Repeat the option 
`-c -c` to also compress the resulting json.

## Using Typed Array JSON in JS

You need to first load the two files we prepared. I will give
a basic (non-working) example that should get you started.
Normally you will use `jQuery.ajax` or `THREE.FileLoader`. Make
sure that you load one as `json` and the other as
`arraybuffer` to get the expected `response` types.

```js
// fetch json with buffer mappings
var dataUrl = "data/model.jdb";
var xmlhttpData = new XMLHttpRequest();
// xmlhttpData.onreadystatechange = ...
xmlhttpData.responseType = "json";
xmlhttpData.open("GET", dataUrl, true);
xmlhttpData.send();
// fetch binary buffers for mappings
var dbUrl = "data/model.jbdb";
var xmlhttpDb = new XMLHttpRequest();
// xmlhttpDb.onreadystatechange = ...
xmlhttpDb.responseType = "arraybuffer";
xmlhttpDb.open("GET", dbUrl, true);
xmlhttpDb.send();
```

Once you have loaded both files (Tip: `Promise.all`), you simply
need to pass both loaded objects into `TypedJson` to re-create
the original JSON with Typed Arrays mixed in.

```js
var json = TypedJson(data, buffer, [offset]);
```

This will actually alter the original `data`. Subsequent calls with the
same `data` will always return the same `json`. Passing in a different
`buffer` or `offset` does not have any effect and is silently ignored!
If you need this, make sure to deep clone `data` before passing it to
`TypedJson`. In most cases we want to avoid a copy here.

## Supported Types

- [Float64Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Float64Array)
- [Float32Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Float32Array)
- [Uint32Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint32Array)
- [Int32Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Int32Array)
- [Uint16Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint16Array)
- [Int16Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Int16Array)
- [Uint8Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array)
- [Int8Array](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Int8Array)

## File Format

The format is pretty simple and was designed to be easily
readable by JavaScript. In order to do this, we only need
to follow a few key principles. TypedArrays want certain
offset addresses (i.e. a multiple of 4 bytes). We achieve
this by putting the types with the biggest byte size first.

### Header

Every file is prefixed with a static `jbdb` string (4 bytes,
Uint32 value 1650745962). Next are four reserved bytes, which
I currently expect to be zero (may use this for extensions).
At offset byte 8 comes a Uint32 value for the expected size.

`Prefix (4 bytes) - Reserverd (4 bytes) - Size (4 bytes)`

### Meta-Data

#### Number of Typed Arrays

Meta data start after the 12 header bytes. It can be split into
a fixed and a dynamic part. The fixed part consists of 8 Uint32
values, thus making the meta part always at least 32bytes long.
There are exactly 8 different typed arrays and each number tells
us how many of each type we have stored.

The full fixed part (header + counters) is 44 bytes, which is
where the dynamic part starts. Every typed array (in specific
order from biggest to smallest) has a pair of Uint32 values
for the relative byte offset (starting from buffer-data) and
the number of items in the array (length).

#### Buffer for Typed Arrays

The offset address for the main buffer data is dynamic and can be
calculated with the following formula:

```js
var base = 12 + 32 + 2 * 4 * nrOfAllArrays
```

Typed arrays can simply be created from the provided meta-data:

```js
new Float32Array(buffer, base + offset, length)
```

## Postamble

The gained size reduction is rather small once you apply `lzma`
compression. A 1.5MB JSON is reduced to 220KB with compression.
Compared to that the compressed array buffer resulted in 180KB.
The main gain comes from the fact that the browser does not have
to re-create and parse the 1.5MB JSON file.

## Copyright

© 2017 [Marcel Greter][1]

[1]: https://github.com/mgreter
[2]: http://www.7-zip.org/sdk.html
[3]: https://github.com/jcmellado/js-lzma