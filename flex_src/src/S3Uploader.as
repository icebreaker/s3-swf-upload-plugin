package  {
	import flash.events.*;
	import flash.external.*;
	import flash.net.*;
	import flash.display.*;
	import flash.system.Security;
	import flash.xml.XMLDocument;                                                                                                 
	import flash.xml.XMLNode;
	import com.elctech.*;
	import com.nathancolgate.*;
	
	public class S3Uploader extends Sprite {
		public var id:String;

		private var multipleFileDialogBox:FileReferenceList;
		private var singleFileDialogBox:FileReference;
		private var fileFilter:FileFilter;

		private var queue:Array;
		private var options:Object;
		private var signature:S3Signature;
		private var request:S3UploadRequest;
		private var file:Object;

		public function S3Uploader() 
		{
			super();
			this.id = LoaderInfo(root.loaderInfo).parameters.id;
			registerCallbacks();
		}

		private function registerCallbacks():void 
		{
			if (ExternalInterface.available) 
			{
				ExternalInterface.addCallback("init", init);
				ExternalInterface.addCallback("start", start);
				ExternalInterface.addCallback("cancel", cancel);
				ExternalInterface.call("s3_upload.init", this.id);
			}
		}

		private function init(options:Object):void 
		{
			file = null;
			this.options = options;

			flash.system.Security.allowDomain("*");
			addChild(new BrowseButton(options.width, options.height, options.upImg, options.downImg, options.overImg, options.hideButton));

			stage.showDefaultContextMenu = false;
			stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
			stage.align = flash.display.StageAlign.TOP_LEFT;

			this.addEventListener(MouseEvent.CLICK, clickHandler);

			fileFilter				= new FileFilter(options.fileDesc, options.fileExt);
			multipleFileDialogBox	= new FileReferenceList;
			singleFileDialogBox		= new FileReference;

			multipleFileDialogBox.addEventListener(Event.SELECT, selectFileHandler);
			singleFileDialogBox.addEventListener(Event.SELECT, selectFileHandler);

			queue = new Array();
		}

		private function start():void
		{
			uploadNextFile();
		}

		private function cancel(file_id:String):void
		{
			if(file && file.id == file_id)
			{
				ExternalInterface.call("s3_upload.callback", 
						this.id, 
						'onCancel', 
						new Object(), 
						file.id, 
						file.reference, 
						file.data);

				file.reference.cancel();
			}
			else
			{
				var i:int;
				for (i=0; i<queue.length; i++)
				{
					if(queue[i].id == file_id)
					{
						ExternalInterface.call("s3_upload.callback", 
								this.id, 
								'onCancel', 
								new Object(), 
								queue[i].id, 
								queue[i].reference, 
								queue[i].data);

						queue[i].reference.cancel();
						queue.splice(i, 1);
					}
				}
			}
		}
		
		private function clickHandler(event:Event):void
		{
			if(options.multi)
				multipleFileDialogBox.browse([fileFilter]);
			else 
				singleFileDialogBox.browse([fileFilter]);
		}

		private function selectFileHandler(event:Event):void 
		{
			queue.length = 0;
			
			if(options.multi)
			{
				var i:int;
				for (i=0; i<event.currentTarget.fileList.length; i++)
					addFile(event.currentTarget.fileList[i]);
			} 
			else 
			{
				addFile(FileReference(event.target));
			}
	
			if(options.auto == true)
				uploadNextFile();
		}
		
		private function addFile(file:FileReference):void
		{
			var _file:Object = new Object();
			_file.id = new Date().getTime().toString() + "_" + queue.length.toString();
			_file.reference = file;
			_file.file = new Object();
			_file.file.name = file.name;
			_file.file.size = file.size;
			_file.file.type = file.type;
			_file.data = new Object();

			queue.push(_file);

			ExternalInterface.call("s3_upload.callback", this.id, 'onSelect', new Object(), _file.id, _file.reference, _file.data);
		}

		private function uploadNextFile():void
		{
			if(queue.length > 0)
			{
				file = queue.splice(0,1)[0];

				signature = new S3Signature(file.reference, options.signature, options.params);
				signature.addEventListener(Event.COMPLETE, onSignatureComplete);
				signature.load();
			}
		}

		private function onSignatureComplete(event:Event):void
		{
			request = new S3UploadRequest(signature.upload_options);
			request.addEventListener(Event.OPEN, onOpen);
			request.addEventListener(ProgressEvent.PROGRESS, onProgress);
			request.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			request.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			request.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatus);
			request.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onComplete);
			request.upload(file.reference);
		}

		private function onOpen(event:Event):void
		{
			// empty
		}

		private function onProgress(event:ProgressEvent):void 
		{
			file.data.percentage = Math.ceil(event.bytesLoaded * 100 / event.bytesTotal);
			ExternalInterface.call("s3_upload.callback", this.id, 'onProgress', event, file.id, file.reference, file.data);
		}

		private function onIoError(event:IOErrorEvent):void
		{
			ExternalInterface.call("s3_upload.callback", this.id, 'onError', event, file.id, file.reference, file.data);
		}    

		private function onHttpStatus(event:HTTPStatusEvent):void
		{
			// empty
		}

		private function onSecurityError(event:SecurityErrorEvent):void
		{
			ExternalInterface.call("s3_upload.callback", this.id, 'onError', event, file.id, file.reference, file.data);
		}

		private function onComplete(event:DataEvent):void
		{
			var xml:XMLDocument = new XMLDocument();
			xml.ignoreWhite = true;                                                                                               
			xml.parseXML(event.data);
			var root:XMLNode = xml.firstChild.firstChild.firstChild;

			file.data.url = root.nodeValue;
			ExternalInterface.call("s3_upload.callback", this.id, 'onComplete', event, file.id, file.reference, file.data);

			uploadNextFile();
		}
	}
}
