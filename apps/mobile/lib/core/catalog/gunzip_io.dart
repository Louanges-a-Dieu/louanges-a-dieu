import 'dart:io';

const bool gunzipSupported = true;

List<int> gunzip(List<int> bytes) => gzip.decode(bytes);
