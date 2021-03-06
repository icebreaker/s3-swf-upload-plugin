package com.elctech {

	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.HTTPStatusEvent;
	import flash.events.DataEvent;

	import flash.net.FileReference;
	import flash.net.URLVariables;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;

	import flash.system.Security;
	import flash.xml.XMLDocument;
	import flash.xml.XMLNode;

	/**
	 * This class encapsulates a POST request to S3.
	 * 
	 * After you create an S3PostRequest, invoke S3PostRequest::upload(fileReference:FileReference).
	 * 
	 */
	public class S3UploadRequest extends EventDispatcher {

		[Event(name="open", type="flash.events.Event.OPEN")]
		[Event(name="uploadCompleteData", type="flash.events.DataEvent.UPLOAD_COMPLETE_DATA")]
		[Event(name="ioError", type="flash.events.IOErrorEvent.IO_ERROR")]
		[Event(name="securityError", type="flash.events.SecurityErrorEvent.SECURITY_ERROR")]
		[Event(name="progress", type="flash.events.ProgressEvent.PROGRESS")]

		private var _accessKeyId:String;
		private var _bucket:String;
		private var _key:String;
		private var _options:S3UploadOptions;
		private var _suppressIoError:Boolean;
		private var _uploadStarted:Boolean;
		private var fileReference:FileReference;

		private const ENDPOINT:String = "s3.amazonaws.com";
		private const MIN_BUCKET_LENGTH:int = 3;
		private const MAX_BUCKET_LENGTH:int = 63;

		/**
		 * Creates and initializes a new S3PostRequest object.
		 * @param    accessKeyId The AWS access key id to authenticate the request
		 * @param    bucket The bucket to POST into
		 * @param    key The key to create
		 * @param    options Options for this request
		 */
		public function S3UploadRequest(options:S3UploadOptions) 
		{
			_accessKeyId = options.AWSAccessKeyId;
			_bucket      = options.bucket;
			_key         = options.key;
			_options     = options;
		}

		private function buildUrl():String 
		{
			var canUseVanityStyle:Boolean = canUseVanityStyle(_bucket);
			var postUrl:String = "http" + ((_options.Secure == 'true') ? "s" : "") + "://";

			if(canUseVanityStyle) {
				postUrl += _bucket + "." + ENDPOINT;
			} else {
				postUrl += ENDPOINT + "/" + _bucket;
			}

			return postUrl;
		}

		private function canUseVanityStyle(bucket:String):Boolean 
		{
			if( bucket.length < MIN_BUCKET_LENGTH ||
					bucket.length > MAX_BUCKET_LENGTH ||
					bucket.match(/^\./) ||
					bucket.match(/\.$/) ) {
				return false;
			}

			// must be lower case
			if(bucket.toLowerCase() != bucket) {
				return false;
			}

			// Check not IPv4-like
			if (bucket.match(/^[0-9]|+\.[0-9]|+\.[0-9]|+\.[0-9]|+$/)) {
				return false;
			}

			// Check each label
			if(bucket.match(/\./)) {
				var labels:Array = bucket.split(/\./);
				for (var i:int = 0;i < labels.length; i++) {
					if(!labels[i].match(/^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$/)) {
						return false;
					}
				}
			}

			return true;
		}

		private function loadPolicyFile(postUrl:String):void 
		{
			/*
			 * Due to the restrictions imposed by the Adobe Flash security sandbox,
			 * the bucket being uploaded to must contain a public-readable crossdomain.xml
			 * file that allows access from the domain that served the SWF hosting this code.
			 * 
			 * Read Adobe's documentation on the Flash security sandbox for more information.
			 * 
			 */

			Security.loadPolicyFile(postUrl + "/crossdomain.xml");
		}

		public function removeListeners():void 
		{
			fileReference.removeEventListener(Event.OPEN, onOpen);
			fileReference.removeEventListener(ProgressEvent.PROGRESS, onProgress);
			fileReference.removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
			fileReference.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			fileReference.removeEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onUploadCompleteData);
			fileReference.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatus);
		}
		/**
		 * Initiates a POST upload request to S3
		 * @param    fileReference A FileReference object referencing the file to upload to S3.
		 */
		public function upload(_fileReference:FileReference):void 
		{
			if(_uploadStarted) {
				throw new Error("S3PostRequest object cannot be reused.  Create another S3PostRequest object to send another request to Amazon S3.");
			}
			_uploadStarted = true;
			_suppressIoError = false;

			// Save the FileReference object so that it doesn't get GCed.
			// If this happens, we can lose events that should be dispatched.
			fileReference = _fileReference;

			var postUrl:String = buildUrl();
			loadPolicyFile(postUrl);
			var urlRequest:URLRequest = new URLRequest(postUrl);
			urlRequest.method = URLRequestMethod.POST;
			urlRequest.data = buildPostVariables();

			// set up event handlers *****************************************************
			fileReference.addEventListener(Event.OPEN, onOpen);
			fileReference.addEventListener(ProgressEvent.PROGRESS, onProgress);
			fileReference.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			fileReference.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			fileReference.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onUploadCompleteData);
			fileReference.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatus);
			// *****************************************************************************

			// send the request
			fileReference.upload(urlRequest, "file", false);
		}

		private function buildPostVariables():URLVariables 
		{
			var postVariables:URLVariables = new URLVariables();

			postVariables.key                     = _key;
			postVariables.acl                     = _options.acl;
			postVariables.AWSAccessKeyId          = _accessKeyId;
			postVariables.signature               = _options.signature;
			postVariables["Content-Type"]         = _options.ContentType;
			postVariables["Content-Disposition"]  = _options.ContentDisposition;
			postVariables.policy                  = _options.policy;

			/**
			 * Certain combinations of Flash player version and platform don't handle
			 * HTTP responses with the header 'Content-Length: 0'.  These clients do not
			 * dispatch completion or error events when such a response is received.
			 * Therefore it is impossible to tell when the upload has completed or failed.
			 * 
			 * Flash clients should always set the success_action_status parameter to 201
			 * so that Amazon S3 returns a response with Content-Length being non-zero.
			 * 
			 */
			postVariables.success_action_status = "201";

			return postVariables;
		}
		private function onOpen(event:Event):void 
		{
			this.dispatchEvent(event);
		}
		private function onIOError(event:IOErrorEvent):void 
		{
			if(_suppressIoError)
				return;

			this.dispatchEvent(event);
		}
		private function onSecurityError(event:SecurityErrorEvent):void 
		{
			this.dispatchEvent(event);
		}
		private function onProgress(event:ProgressEvent):void 
		{
			this.dispatchEvent(event);
		}
		private function onUploadCompleteData(event:DataEvent):void 
		{
			this.dispatchEvent(event);
		}
		private function onHttpStatus(event:HTTPStatusEvent):void 
		{
			if(Math.floor(event.status / 100) == 2) // 200, 201
			{
				_suppressIoError = true;

				// TODO: use XML builder
				var data:String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
				data += "<PostResponse>";
					data += "<Location>http://" + _bucket + "." + ENDPOINT + "/" + _key + "</Location>";
					data += "<Bucket>" + _bucket + "</Bucket>";
					data += "<Key>" + _key + "</Key>";
					data += "<ETag>\"3753245fe74b58638afc62b58c15607d\"</ETag>";
				data += "</PostResponse>";

				this.dispatchEvent(new DataEvent(DataEvent.UPLOAD_COMPLETE_DATA, event.bubbles, event.cancelable, data));
			}
			else
			{
				this.dispatchEvent(event);
			}
		}
	}

}
