package com.gamesys.hulk.display.scenes;

import com.gamesys.hulk.asset.loader.TextLoader;
import com.gamesys.hulk.common.types.CommonDisplayTypes;
import com.gamesys.hulk.display.components.AfterEffectsAnimation;

class TestScene_AfterEffectsAnimation extends TestScene
{
	private var _afterEffectsAnimation:AfterEffectsAnimation;


    // CONSTRUCTOR & DESTRUCTOR
	// =============================================================================

    public function new()
    {
		super();

		description = "Tests After Effect Animation";
    }

    override public function destroy():Void
    {
		if(_afterEffectsAnimation != null)
		{
			removeChild(_afterEffectsAnimation);
			_afterEffectsAnimation.destroy();
			_afterEffectsAnimation = null;
		}

        super.destroy();
    }


	// PUBLIC FUNCTIONS
	// =============================================================================

	public override function viewWasAdded():Void
	{
		var _xmlLoader:TextLoader = new TextLoader();
		_xmlLoader.load("images/afterEffectsHansel/intro-Paralax-1024x648@x2.xml", onXmlLoaded);
//		_xmlLoader.load("images/afterEffectsHansel/transition-paralax1024x648@x2.xml", onXmlLoaded);
	}


    // HANDLERS
	// =============================================================================

    private function onXmlLoaded(_data:String):Void
    {
        var xmlString:String = _data;
        var assetsList:Array<String> = [
			"BG.png",
			"Front-L1.png",
			"Front-R.png",
			"house-1.png",
			"house-2.png",
			"house-3.png",
			"House.png",
			"Mid-L.png",
			"Mid-R.png",
			"NEW-god-ray1.png",
			"NEW-god-ray2.png",
			"NEW-god-ray3.png"
		];

        var mapTextures:Map<String, NativeTexture>;
        mapTextures = new Map<String, NativeTexture>();

        for(asset in assetsList)
        {
            var index:Int = asset.lastIndexOf('/');
            var shortName:String = asset.substring(index + 1);
            mapTextures.set(shortName, _assetManager.getTexture(asset));
        }

		_afterEffectsAnimation = new AfterEffectsAnimation();
		_afterEffectsAnimation.sigAnimationComplete.add(onSigAnimationComplete);
		_afterEffectsAnimation.xmlData = xmlString;
		_afterEffectsAnimation.mapTextures = mapTextures;
        addChild(_afterEffectsAnimation);
		_afterEffectsAnimation.play();

		// Good luck with positioning
		_afterEffectsAnimation.x = -_afterEffectsAnimation.width * 0.25;
		_afterEffectsAnimation.y = -_afterEffectsAnimation.height * 0.25;
    }

	private function onSigAnimationComplete(displayObject:DisplayObject):Void
	{
		trace("AFTER EFFECT ANIMATION FINISHED!");
	}
}
