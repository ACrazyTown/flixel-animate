package animate.internal;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMatrix;
import flixel.util.FlxDestroyUtil;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.OpenGLRenderer;
import openfl.display3D.Context3D;
import openfl.display3D.textures.RectangleTexture;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;

@:access(flixel.FlxCamera)
@:access(flixel.graphics.FlxGraphic)
@:access(openfl.display.BitmapData)
@:access(openfl.display.DisplayObjectContainer)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.geom.ColorTransform)
class RenderTexture implements IFlxDestroyable
{
	public var antialiasing:Bool = false;
	public var graphic(default, null):FlxGraphic;

	/**
	 * If enabled, the internal texture will intentionally round up to the 
	 * nearest power of two in an attempt to avoid texture reallocations when resizing.
	 * 
	 * If you're not going to resize the texture often it is best to disable this
	 * to avoid extra memory use.
	 */
	public var usePowerOfTwo:Bool = true;

	var _renderer:OpenGLRenderer;
	var _currentBitmap:BitmapData;
	var _camera:FlxCamera;
	var _matrix:FlxMatrix;

	public function new(width:Int, height:Int):Void
	{
		_renderer = new OpenGLRenderer(FlxG.stage.context3D);
		_renderer.__worldTransform = new Matrix();
		_renderer.__worldColorTransform = new ColorTransform();

		_camera = new FlxCamera();
		_matrix = new FlxMatrix();

		init(width, height);
	}

	public function destroy():Void
	{
		_renderer.__cleanup();
		_renderer = null;

		if (_currentBitmap != null)
		{
			if (_currentBitmap.__texture != null)
				_currentBitmap.__texture.dispose();

			_currentBitmap.dispose();
		}
		_currentBitmap = null;

		_camera = FlxDestroyUtil.destroy(_camera);
		_matrix = null;

		graphic = FlxDestroyUtil.destroy(graphic);
	}

	/**
	 * Initializes the render texture internal data to be used for rendering.
	 * This function **MUST** be called before using ``RenderTexture.render`` if you plan on dynamically
	 * changing the size of the texture from it's initial resolution.
	 * 
	 * @param width New width of the texture.
	 * @param height New height of the texture.
	 * 
	 */
	public function init(width:Int, height:Int):Void
	{
		_camera.clearDrawStack();
		_camera.canvas.graphics.clear();
		#if FLX_DEBUG
		_camera.debugLayer.graphics.clear();
		#end
		_camera.width = width;
		_camera.height = height;

		_prepareTexture(width, height);
		graphic.bitmap = _currentBitmap;
		graphic.imageFrame.frame.frame.set(0, 0, width, height);

		_currentBitmap.__fillRect(_currentBitmap.rect, 0, true);
	}

	/**
	 * Provides a way to add custom draw contents onto the internal camera of the texture.
	 * Used a custom callback which supplies the ``FlxCamera`` to render to and a usable helper identity ``FlxMatrix``.
	 * 
	 * @param drawCallback Custom callback with the internal ``FlxCamera`` and helper ``FlxMatrix``.
	 * 
	 */
	public function drawToCamera(drawCallback:FlxCamera->FlxMatrix->Void):Void
	{
		_matrix.identity();
		drawCallback(_camera, _matrix);
	}

	/**
	 * Renders the drawn contents of the internal camera onto the texture.
	 */
	public function render():Void
	{
		_camera.render();
		_camera.canvas.__update(false, true);

		_renderer.__cleanup();

		_renderer.setShader(_renderer.__defaultShader);
		_renderer.__allowSmoothing = antialiasing;
		_renderer.__pixelRatio = #if openfl_disable_hdpi 1 #else Lib.current.stage.window.scale #end;
		_renderer.__worldAlpha = 1 / _camera.canvas.__worldAlpha;
		_renderer.__worldTransform.copyFrom(_camera.canvas.__renderTransform);
		_renderer.__worldTransform.invert();
		_renderer.__worldColorTransform.__copyFrom(_camera.canvas.__worldColorTransform);
		_renderer.__worldColorTransform.__invert();
		_renderer.__setRenderTarget(_currentBitmap);

		_currentBitmap.__drawGL(_camera.canvas, _renderer);
	}

	function _prepareTexture(width:Int, height:Int):Void
	{
		var w = usePowerOfTwo ? _powerOfTwo(width) : width;
		var h = usePowerOfTwo ? _powerOfTwo(height) : height;

		var requireTexture = _currentBitmap == null || (w > _currentBitmap.width || h > _currentBitmap.height);
		if (!requireTexture)
			return;

		if (_currentBitmap != null)
		{
			if (_currentBitmap.__texture != null)
				_currentBitmap.__texture.dispose();

			_currentBitmap.dispose();
		}

		_currentBitmap = BitmapData.fromTexture(FlxG.stage.context3D.createRectangleTexture(w, h, BGRA, true));

		if (graphic == null)
			graphic = FlxGraphic.fromBitmapData(_currentBitmap, false, null, false);

	}

	inline function _powerOfTwo(value:Int):Int
	{
		var n = 1;
		while (n < value)
			n <<= 1;
		return n;
	}
}
