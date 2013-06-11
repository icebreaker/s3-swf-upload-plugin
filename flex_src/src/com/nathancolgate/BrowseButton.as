package com.nathancolgate {

	import flash.display.SimpleButton;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.net.URLRequest;

	public dynamic class BrowseButton extends Sprite {

		private var _playButton:SimpleButton;

		public function BrowseButton(
				width:Number,
				height:Number,
				upUrl:String,
				downUrl:String,
				overUrl:String,
				hide:Boolean)
		{
			super();

			_playButton = new SimpleButton();
			_playButton.useHandCursor = true;
			addChild(_playButton);

			// Hit Test
			var hit_test:Shape = new Shape();            
			hit_test.graphics.beginFill(0xFFCC00);
			hit_test.graphics.drawRect(0, 0, width, height);            
			hit_test.graphics.endFill();
			_playButton.hitTestState = hit_test;

			if(hide == false)
			{
				// Up
				var upLoader:Loader = new Loader();
				upLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void
				{
					_playButton.upState = new Bitmap(e.target.content.bitmapData);
				});
				upLoader.load(new URLRequest(upUrl));

				// Down
				var downLoader:Loader = new Loader();
				downLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void
				{ 
					_playButton.downState = new Bitmap(e.target.content.bitmapData);
				});
				downLoader.load(new URLRequest(downUrl));

				// Over
				var overLoader:Loader = new Loader();
				overLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void
				{
					_playButton.overState = new Bitmap(e.target.content.bitmapData);
				});
				overLoader.load(new URLRequest(overUrl));
			}
		}
	}
}
