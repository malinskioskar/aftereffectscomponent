package com.gamesys.hulk.display.components;

import com.gamesys.hulk.logger.Logger;
import motion.easing.Linear;
import com.gamesys.hulk.common.types.CommonDisplayTypes;
import com.gamesys.hulk.display.geom.Point;
import motion.Actuate;
import msignal.Signal;

class AfterEffectsAnimation extends Container
{
    private static inline var GROUP_TRANSFORM_NAME:String = "Transform";
    private static inline var PROPERTY_ANCHOR_NAME:String = "Anchor_Point";
    private static inline var KEY_POSITION_NAME:String = "Position";
    private static inline var KEY_ROTATION_NAME:String = "Rotation";
    private static inline var KEY_OPACITY_NAME:String = "Opacity";
    private static inline var KEY_SCALE_NAME:String = "Scale";

    private var _layerList:Array<AfterEffectsAnimationLayer>;
    private var _clips:Array<MovieClip>;
    private var _images:Array<Sprite>;
    private var _elements:Array<Sprite>;
    private var _mapTextures:Map<String, NativeTexture>;
    private var _xmlData:String;
    private var _xmlFile:Xml;
    private var _duration:Float;


    // CONSTRUCTOR & DESTRUCTOR
    // =============================================================================

    public function new()
    {
        super();

        bucketScale = 1.0;
        animationScale = 2.0;

        sigLayerDidShow = new Signal1<DisplayObject>();
        sigLayerDidHide = new Signal1<DisplayObject>();

        sigAnimationComplete = new Signal1<DisplayObject>();
    }

    override public function destroy():Void
    {
        stop();

        _elements = null;
        _clips = null;
        _images = null;
        _xmlFile = null;

        if(sigAnimationComplete != null)
        {
            sigAnimationComplete.removeAll();
            sigAnimationComplete = null;
        }

	    if(sigLayerDidShow != null)
	    {
            sigLayerDidShow.removeAll();
            sigLayerDidShow = null;
	    }

        if(sigLayerDidHide != null)
        {
            sigLayerDidHide.removeAll();
            sigLayerDidHide = null;
        }

        super.destroy();
    }


    // ACCESSORS & MUTATORS
    // =============================================================================
    public var sigLayerDidShow(default, null):Signal1<DisplayObject>;
    public var sigLayerDidHide(default, null):Signal1<DisplayObject>;

	public var sigAnimationComplete(default, null):Signal1<DisplayObject>;

	public var xmlData(null, set):String;
    private function set_xmlData(value:String):String
    {
        _xmlData = value;

        xmlFile = Xml.parse(value);

        return _xmlData;
    }

    public var xmlFile(null, set):Xml;
    private function set_xmlFile(value:Xml):Xml
    {
        _xmlFile = value;

        _layerList = getLayerLists(_xmlFile);

        if (_layerList != null && _mapTextures != null)
        {
            prepareDisplayObjects();
        }
        return _xmlFile;
    }

    public var mapTextures(null, set):Map<String, NativeTexture>;
    private function set_mapTextures(value:Map<String, NativeTexture>):Map<String, NativeTexture>
    {
        _mapTextures = value;

        if (_layerList != null && _mapTextures != null)
        {
            prepareDisplayObjects();
        }
        return _mapTextures;
    }

    //SCALE OF BUCKET IN USE
    public var bucketScale(null, set):Float;
    private function set_bucketScale(value:Float):Float
    {
        return bucketScale = value;
    }

    //SCALE OF ANIMATION
    public var animationScale(null, set):Float;
    private function set_animationScale(value:Float):Float
    {
        return animationScale = value;
    }


    // PUBLIC FUNCTIONS
    // =============================================================================

    /**
	 * Plays the Animation.
	 */
    public function play():Void
    {
        var canComplete:Bool = false;
        var waitingForTweenLayers:Array<AfterEffectsAnimationLayer> = new Array<AfterEffectsAnimationLayer>();

        function checkForCompleteCallback()
        {
            if (canComplete && waitingForTweenLayers.length == 0)
            {
				sigAnimationComplete.dispatch(this);
            }
        }

        for (layer in _layerList)
        {
            var element:Sprite = layer.element;
            if (element == null)
            {
                continue;
            }

            function hideElementFunction()
            {
                sigLayerDidHide.dispatch(element);
                element.visible = false;
            }

            function showElementFunction()
            {
                element.visible = true;
                sigLayerDidShow.dispatch(element);
            }

            Actuate.timer(layer.lifetime.start).onComplete(showElementFunction);
            if(_duration != layer.lifetime.end)
            {
                Actuate.timer(layer.lifetime.end).onComplete(hideElementFunction);
            }

            element.width = layer.width;
            element.height = layer.height;

            for (group in layer.groupList)
            {
                if (group.name == GROUP_TRANSFORM_NAME)
                {
                    function tweenCompleteCallback()
                    {
                        waitingForTweenLayers.remove(layer);

                        checkForCompleteCallback();
                    }

                    waitingForTweenLayers.push(layer);

                    runTweensForElementPropertyList(element, group.propertyList, tweenCompleteCallback);
                }
            }

            if (Std.is(element, MovieClip))
            {
                var clip:MovieClip = cast(element);
                clip.loop = false;
                clip.currentFrame = 0;
                clip.play();
            }
        }

        canComplete = true;
        checkForCompleteCallback();
    }


    /**
	 * Stops the MovieClip.
	 */
    public function stop():Void
    {
        if (_clips != null)
        {
            for (clip in _clips)
            {
                clip.loop = false;
                clip.stop();
                Actuate.stop(clip);
            }
        }

        if (_images != null)
        {
            for (image in _images)
            {
                Actuate.stop(image);
            }
        }
    }


    // PRIVATE FUNCTIONS
    // =============================================================================

    private function showFirstFrame()
    {
        for (layer in _layerList)
        {
            var element:Sprite = layer.element;

            if (element != null)
            {
                element.width = layer.width;
                element.height = layer.height;

                for (group in layer.groupList)
                {
                    if (group.name == GROUP_TRANSFORM_NAME)
                    {
                        for (property in group.propertyList)
                        {
                            if (property.keyList.length > 0)
                            {
                                if (property.type == PROPERTY_ANCHOR_NAME)
                                {
                                    var anchorKey:AfterEffectsAnimationKeyAnchor = cast(property.keyList[0]);
                                    element.pivotX = anchorKey.pivotPoint.x;
                                    element.pivotY = anchorKey.pivotPoint.y;
                                }
                                else if (property.type == KEY_ROTATION_NAME)
                                {
                                    var rotationKey:AfterEffectsAnimationKeyRotation = cast(property.keyList[0]);
                                    element.rotation = rotationKey.rotationValue;
                                }
                                else if (property.type == KEY_OPACITY_NAME)
                                {
                                    var opacityKey:AfterEffectsAnimationKeyOpacity = cast(property.keyList[0]);
                                    element.alpha = opacityKey.opacityValue;
                                }
                                else if (property.type == KEY_POSITION_NAME)
                                {
                                    var positionKey:AfterEffectsAnimationKeyPosition = cast(property.keyList[0]);
                                    element.x = positionKey.positionPoint.x;
                                    element.y = positionKey.positionPoint.y;
                                }
                                else if (property.type == KEY_SCALE_NAME)
                                {
                                    var scaleKey:AfterEffectsAnimationKeyScale = cast(property.keyList[0]);
                                    element.scaleX = scaleKey.scaleX;
                                    element.scaleY = scaleKey.scaleY;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private function generateFilepathPiece(value:Int, ?maxDigits:Int = 5):String
    {
        var finalString:String = "";
        var valueToString:String = Std.string(value);

        for (layerIndex in valueToString.length...maxDigits)
        {
            finalString += "0";
        }
        finalString += valueToString;
        return finalString;
    }

    private function runTweensForElementPropertyList(element:Sprite, propertyList:Array<AfterEffectsAnimationProperty>, ?completeCallback:Void -> Void = null)
    {
        var supportedTweenKeys = [KEY_POSITION_NAME, KEY_ROTATION_NAME, KEY_OPACITY_NAME, KEY_SCALE_NAME];

        var canComplete:Bool = false;
        var waitingForTweenKeys:Array<String> = new Array<String>();

        function checkForCompleteCallback()
        {
            if (canComplete && waitingForTweenKeys.length == 0 && completeCallback != null)
            {
                completeCallback();
            }
        }

        function tweenCompleteCallback(type:String)
        {
            waitingForTweenKeys.remove(type);

            checkForCompleteCallback();
        }

        for (property in propertyList)
        {
            if (property.type == PROPERTY_ANCHOR_NAME)
            {
                if (property.keyList.length == 1)
                {
                    var anchorKey:AfterEffectsAnimationKeyAnchor = cast(property.keyList[0]);
                    element.pivotX = anchorKey.pivotPoint.x;
                    element.pivotY = anchorKey.pivotPoint.y;
                }
            }
            else if (supportedTweenKeys.indexOf(property.type) != -1)
            {
                waitingForTweenKeys.push(property.type);

                runTweensForDisplayObject(property, element, tweenCompleteCallback);
            }
        }

        canComplete = true;
        checkForCompleteCallback();
    }

    private function runTweensForDisplayObject(currentProperty:AfterEffectsAnimationProperty, img:DisplayObject, ?completeCallback:String -> Void = null):Void
    {
        function tweenCompleteCallback()
        {
            if (completeCallback != null)
            {
                completeCallback(currentProperty.type);
            }
        }

        if (currentProperty.keyList.length > 0)
        {
            var previousTime:Float = -1;
            var currentTime:Float;
            var index:Int = 0;

            for (key in currentProperty.keyList)
            {
                var isLast:Bool = index == currentProperty.keyList.length - 1;

                currentTime = key.time;
                var tweenDuration:Float = (previousTime == -1) ? 0 : (currentTime - previousTime);
                var tweenDelay:Float = (previousTime == -1) ? currentTime : previousTime;

                if (currentProperty.type == KEY_ROTATION_NAME)
                {
                    var rotationKey:AfterEffectsAnimationKeyRotation = cast(key);
                    Actuate.tween(img, tweenDuration, { rotation: rotationKey.rotationValue }, false).delay(tweenDelay).onComplete(isLast ? tweenCompleteCallback : null, null).ease(Linear.easeNone);
                }
                else if (currentProperty.type == KEY_OPACITY_NAME)
                {
                    var opacityKey:AfterEffectsAnimationKeyOpacity = cast(key);
                    Actuate.tween(img, tweenDuration, { alpha: opacityKey.opacityValue }, false).delay(tweenDelay).onComplete(isLast ? tweenCompleteCallback : null, null).ease(Linear.easeNone);
                }
                else if (currentProperty.type == KEY_POSITION_NAME)
                {
                    var positionKey:AfterEffectsAnimationKeyPosition = cast(key);
                    Actuate.tween(img, tweenDuration, { x: positionKey.positionPoint.x, y: positionKey.positionPoint.y }, false).delay(tweenDelay).onComplete(isLast ? tweenCompleteCallback : null, null).ease(Linear.easeNone);
                }
                else if (currentProperty.type == KEY_SCALE_NAME)
                {
                    var scaleKey:AfterEffectsAnimationKeyScale = cast(key);
                    Actuate.tween(img, tweenDuration, { scaleX: scaleKey.scaleX, scaleY: scaleKey.scaleY }, false).delay(tweenDelay).onComplete(isLast ? tweenCompleteCallback : null, null).ease(Linear.easeNone);
                }

                previousTime = key.time;

                ++index;
            }
        }
        else
        {
            tweenCompleteCallback();
        }
    }

    private function getLayerLists(xmlFile:Xml):Array<AfterEffectsAnimationLayer>
    {
        _duration = 0;
        var xmlComposition:Xml = xmlFile.firstElement().firstElement();
        var layerList:Array<AfterEffectsAnimationLayer> = new Array<AfterEffectsAnimationLayer>();

        for (layerXML in xmlComposition.elements())
        {
            var singleLayer:AfterEffectsAnimationLayer = {index:layerXML.get("index"),
                name:layerXML.get("name"),
                textures:getLayerTextureNames(layerXML.get("name")),
                width:Std.parseFloat(layerXML.get("width")),
                height:Std.parseFloat(layerXML.get("height")),
                lifetime: { start: Std.parseFloat(layerXML.get("in")), end: Std.parseFloat(layerXML.get("out")) },
                groupList:parseGroups(layerXML)};

            if(singleLayer.lifetime.end > _duration)
            {
                _duration = singleLayer.lifetime.end;
            }

            layerList.push(singleLayer);
        }
        return layerList;
    }

    private function getLayerTextureNames(name:String):Array<String>
    {
        var listOfTextures:Array<String> = new Array<String>();
        var regExp:EReg = ~/\[([0-9]+)\-([0-9]+)\]/;
        var isRange:Bool = regExp.match(name);
        if (isRange)
        {
            var firstValueString:String = regExp.matched(1);
            var lastValueString:String = regExp.matched(2);

            var firstValue:Int = Std.parseInt(firstValueString);
            var lastValue:Int = Std.parseInt(lastValueString);
            var numberOfMovieClips:Int = lastValue - firstValue + 1;

            var matchedLeft:String = regExp.matchedLeft();
            var matchedRight:String = regExp.matchedRight();

            var maxDigits:Null<Int> = firstValueString.length == lastValueString.length ? firstValueString.length : null;

            #if debug
            if (maxDigits == null)
            {
                Logger.debug(this, "After Effects Animation Texture Range Lengths Not Equal: " + name);
            }
            #end

            for (textureIndex in 0...numberOfMovieClips)
            {
                var nameOfTexture:String = matchedLeft + generateFilepathPiece(textureIndex, maxDigits) + matchedRight;
                listOfTextures.push(nameOfTexture);
            }
        }
        else
        {
            listOfTextures.push(name);
        }

        return listOfTextures;
    }

    private function parseGroups(layerXML:Xml):Array<AfterEffectsAnimationGroup>
    {
        var dynamicList:Array<AfterEffectsAnimationGroup> = [];
        for (groupXML in layerXML.elementsNamed("group"))
        {
            var singleGroup:AfterEffectsAnimationGroup = {name:groupXML.get("name"), propertyList:parseProperties(groupXML)};
            dynamicList.push(singleGroup);
        }
        return dynamicList;
    }

    private function parseProperties(groupXML:Xml):Array<AfterEffectsAnimationProperty>
    {
        var dynamicList:Array<AfterEffectsAnimationProperty> = [];
        for (propertyXML in groupXML.elementsNamed("property"))
        {
            var singleProperty:AfterEffectsAnimationProperty = {type:propertyXML.get("type"), keyList:parseKeys(propertyXML, propertyXML.get("type"))};
            dynamicList.push(singleProperty);
        }

        return dynamicList;
    }

    private function parseKeys(propertyXML:Xml, type:String):Array<AfterEffectsAnimationKey>
    {
        var dynamicList:Array<AfterEffectsAnimationKey> = [];
        for (keyXML in propertyXML.elementsNamed("key"))
        {
            var singleKey:AfterEffectsAnimationKey = {value:keyXML.get("value"),
                time:Std.parseFloat(keyXML.get("time"))};

            var scaleModifier:Float = bucketScale / animationScale;

            if (type == PROPERTY_ANCHOR_NAME)
            {
                var anchorKey:AfterEffectsAnimationKeyAnchor = cast(singleKey);
                var anchorArray:Array<String> = singleKey.value.split(",");
                anchorKey.pivotPoint = new Point(Std.parseFloat(anchorArray[0]) * scaleModifier, Std.parseFloat(anchorArray[1]) * scaleModifier);
                dynamicList.push(anchorKey);
            }
            else if (type == KEY_POSITION_NAME)
            {
                var positionKey:AfterEffectsAnimationKeyPosition = cast(singleKey);
                var positionArray:Array<String> = singleKey.value.split(",");
                positionKey.positionPoint = new Point(Std.parseFloat(positionArray[0]) * scaleModifier, Std.parseFloat(positionArray[1]) * scaleModifier);
                dynamicList.push(positionKey);
            }
            else if (type == KEY_OPACITY_NAME)
            {
                var opacityKey:AfterEffectsAnimationKeyOpacity = cast(singleKey);
                opacityKey.opacityValue = Std.parseInt(singleKey.value) / 100;
                dynamicList.push(opacityKey);
            }
            else if (type == KEY_ROTATION_NAME)
            {
                var rotationKey:AfterEffectsAnimationKeyRotation = cast(singleKey);
                rotationKey.rotationValue = Std.parseFloat(singleKey.value) * Math.PI / 180;
                dynamicList.push(rotationKey);
            }
            else if (type == KEY_SCALE_NAME)
            {
                var scaleKey:AfterEffectsAnimationKeyScale = cast(singleKey);
                var tempArray:Array<String> = singleKey.value.split(",");
                scaleKey.scaleX = Std.parseFloat(tempArray[0]) / 100;
                scaleKey.scaleY = Std.parseFloat(tempArray[1]) / 100;
                dynamicList.push(scaleKey);
            }

        }
        return dynamicList;
    }

    private function prepareDisplayObjects():Void
    {
        _images = new Array<Sprite>();
        _clips = new Array<MovieClip>();
        _elements = new Array<Sprite>();

        for (layer in _layerList)
        {
            if (layer.textures.length > 1)
            {
                var nativeArray:NativeTextureArray = new NativeTextureArray();

                for (textureName in layer.textures)
                {
                    if (_mapTextures.exists(textureName))
                    {
                        nativeArray.push(_mapTextures[textureName]);
                    }
                }

                if (nativeArray.length > 0)
                {
                    var movieClip:MovieClip = new MovieClip(nativeArray);
                    movieClip.name = layer.textures[0];
                    layer.element = movieClip;
                    _clips.push(movieClip);
                    _elements.insert(0, movieClip);
                }
            }
            else
            {
                if (layer.textures.length == 1)
                {
                    if (_mapTextures.exists(layer.textures[0]))
                    {
                        var sprite:Sprite = new Sprite(_mapTextures[layer.textures[0]]);
                        sprite.name = layer.textures[0];
                        layer.element = sprite;
                        _images.push(sprite);
                        _elements.insert(0, sprite);
                    }
                }
            }
        }

        for (element in _elements)
        {
            if (element.parent == null)
            {
                addChild(element);
                element.visible = false;
            }
        }

        showFirstFrame();
    }
}


typedef AfterEffectsAnimationLayer =
{
    var index:String; //layering
    var name:String; //asset name
    var textures:Array<String>;
    var lifetime:AfterEffectsLifeTimeKey;
    @:optional var element:Sprite;
    @:optional var width:Float;
    @:optional var height:Float;
    @:optional var groupList:Array<AfterEffectsAnimationGroup>;
}

typedef AfterEffectsAnimationGroup =
{
    var name:String;
    @:optional var propertyList:Array<AfterEffectsAnimationProperty>;
}

typedef AfterEffectsAnimationProperty =
{
    var type:String;
    @:optional var keyList:Array<AfterEffectsAnimationKey>;
}

typedef AfterEffectsLifeTimeKey =
{
    var start:Float;
    var end:Float;
}

typedef AfterEffectsAnimationKey =
{
    var value:String;
    var time:Float;
}

typedef AfterEffectsAnimationKeyAnchor =
{
> AfterEffectsAnimationKey,
    var pivotPoint:Point;
}

typedef AfterEffectsAnimationKeyPosition =
{
> AfterEffectsAnimationKey,
    var positionPoint:Point;
}

typedef AfterEffectsAnimationKeyOpacity =
{
> AfterEffectsAnimationKey,
    var opacityValue:Float;
}

typedef AfterEffectsAnimationKeyRotation =
{
> AfterEffectsAnimationKey,
    var rotationValue:Float;
}

typedef AfterEffectsAnimationKeyScale =
{
> AfterEffectsAnimationKey,
    var scaleX:Float;
    var scaleY:Float;
}
