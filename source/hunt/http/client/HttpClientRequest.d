module hunt.http.client.HttpClientRequest;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

class HttpClientRequest : HttpRequest {

	this(string method, string uri) {
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields());
	}

	this(string method, string uri, int contentLength) {
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields(), contentLength);
	}
	
	this(string method, HttpURI uri, HttpFields fields, long contentLength) {
		super(method, uri, HttpVersion.HTTP_1_1, new HttpFields(), contentLength);
	}
	
	this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, long contentLength) {
		super(method, uri, ver, new HttpFields(), contentLength);
	}

	this(HttpRequest request) {
		super(request);
	}
}
