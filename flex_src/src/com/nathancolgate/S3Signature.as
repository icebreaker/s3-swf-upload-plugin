package com.nathancolgate {
	import com.elctech.S3UploadOptions;
	import com.adobe.net.MimeTypeMap;

	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.HTTPStatusEvent;
	import flash.events.DataEvent;
	import flash.external.ExternalInterface;

	import flash.net.FileReference;
	import flash.net.URLVariables;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLRequestHeader;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;

	public class S3Signature extends EventDispatcher 
	{
		[Event(name="complete", type="flash.event.COMPLETE")]

		public var upload_options:S3UploadOptions;

		private var signatureLoader:URLLoader;
		private var request:URLRequest;

		public function S3Signature(file:FileReference, signature:String, params:Object) 
		{
			upload_options					= new S3UploadOptions;
			upload_options.FileSize         = file.size.toString();
			upload_options.FileName         = getFileName(file);
			upload_options.ContentType      = getContentType(upload_options.FileName);
			upload_options.key              = upload_options.FileName;

			var variables:URLVariables			= new URLVariables();
			variables.key						= upload_options.key;
			variables.content_type				= upload_options.ContentType;

			var key:String;
			for(key in params)
				variables[key] = params[key];

			request			= new URLRequest(signature);
			request.method	= URLRequestMethod.GET;
			request.data	= variables;

			/*
			var header:URLRequestHeader;
			for(key in params)
			{
				header = new URLRequestHeader(key, params[key]);
				request.requestHeaders.push(header);
			}
			*/

			signatureLoader	= new URLLoader();
			signatureLoader.dataFormat = URLLoaderDataFormat.TEXT;
			signatureLoader.addEventListener(Event.COMPLETE, onComplete);
		}
		
		public function load():void
		{
			signatureLoader.load(request);
		}

		private function onComplete(event:Event):void
		{
			var loader:URLLoader = URLLoader(event.target);
			var xml:XML  = new XML(loader.data);

			upload_options.policy				= xml.policy;
			upload_options.signature			= xml.signature;
			upload_options.bucket				= xml.bucket;
			upload_options.AWSAccessKeyId		= xml.accesskeyid;
			upload_options.acl					= xml.acl;
			upload_options.Expires				= xml.expirationdate;
			upload_options.Secure				= xml.https;
			upload_options.key					= xml.key;
			upload_options.ContentDisposition	= xml.contentdisposition;

			dispatchEvent(event);
		}

		private function getContentType(fileName:String):String 
		{
			var fileNameArray:Array		= fileName.split(/\./);
			var fileExtension:String	= fileNameArray[fileNameArray.length - 1];
			var mimeMap:MimeTypeMap		= new MimeTypeMap;
			var contentType:String		= mimeMap.getMimeType(fileExtension);
			return contentType;
		}

		private function getFileName(file:FileReference):String 
		{
			var fileName:String = file.name.replace(/^.*(\\|\/)/gi, '').replace(/[^A-Za-z0-9\.\-]/gi, '_');
			return fileName;
		}
	}
}
