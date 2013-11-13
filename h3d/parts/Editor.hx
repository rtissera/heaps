package h3d.parts;
import h3d.parts.Data;

@:bitmap("h3d/parts/default.png") private class DefaultPart extends flash.display.BitmapData {
}

@:bitmap("h3d/parts/defaultAlpha.png") private class DefaultPartAlpha extends flash.display.BitmapData {
}

private typedef Curve = {
	var value : Value;
	var name : String;
	var incr : Float;
	var mode : Int;
	var min : Float;
	var max : Float;
	var pow : Float;
	var freq : Float;
	var ampl : Float;
}

class Editor extends h2d.Sprite {
	
	var emit : Emiter;
	var state : State;
	var curState : String;
	var width : Int;
	var height : Int;
	var ui : h2d.comp.Component;
	var stats : h2d.comp.Label;
	var cachedMode : BlendMode;
	var lastPartSeen : Null<Float>;
	var props : {
		startTime : Float,
		pause : Bool,
	};
	var curve : Curve;
	var curveBG : h2d.Tile;
	var curveTexture : h2d.Tile;
	var grad : h2d.comp.GradientEditor;
	
	static var CURVES : Array<{ name : String, f : Curve -> Data.Value }> = [
		{ name : "Const", f : function(c) return VConst(c.min) },
		{ name : "Linear", f : function(c) return VLinear(c.min, c.max - c.min) },
		{ name : "Pow", f : function(c) return VPow(c.min, c.max - c.min, c.pow) },
		{ name : "Random", f : function(c) return VRandom(c.min, c.max - c.min) },
	];
	
	public function new(emiter, ?parent) {
		super(parent);
		this.emit = emiter;
		this.state = emit.state;
		props = {
			startTime : 0.,
			pause : false,
		};
		curve = {
			value : null,
			name : null,
			mode : -1,
			incr : 0.01,
			min : 0.,
			max : 1.,
			freq : 1.,
			ampl : 1.,
			pow : 1.,
		};
		initCurve(VLinear(0, 1));
		init();
		buildUI();
	}

	function buildUI() {
		if( ui != null ) ui.remove();
		ui = h2d.comp.Parser.fromHtml('
			<body class="body">
				<style>
					* {
						font-size : 12px;
					}

					.body {
						layout : dock;
					}
					
					span {
						padding-top : 2px;
					}

					.main {
						padding : 15px;
						width : 202px;
						dock : left;
						layout : vertical;
						vertical-spacing : 10px;
					}

					.col {
						layout : vertical;
					}
					
					.col.buttons {
						layout : inline;
					}

					.line {
						layout : horizontal;
					}
					
					.ic, .icol {
						icon : url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAB3RJTUUH3QsHEDot9CONhQAAABd0RVh0U29mdHdhcmUAR0xEUE5HIHZlciAzLjRxhaThAAAACHRwTkdHTEQzAAAAAEqAKR8AAAAEZ0FNQQAAsY8L/GEFAAAABmJLR0QA/wD/AP+gvaeTAAAARklEQVR4nGP4z/CfJMRAmQYIIFbDfwwGJvpPHQ249PxHdtJ/LHKkaMBtBAN+80jRgCMY8GrAFjMMBGMKI+Jor4EU1eRoAADB1BsCKErgdwAAAABJRU5ErkJggg=");
						icon-top : 1px;
						icon-left : 2px;
						icon-color : #888;
						padding-left : 20px;
					}
					
					.ic:hover, .icol:hover {
						icon-top : 0px;
					}
					
					.icol {
						icon-color : #AAA;
						icon : url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAB3RJTUUH3QsICwAiCSUSqgAAABd0RVh0U29mdHdhcmUAR0xEUE5HIHZlciAzLjRxhaThAAAACHRwTkdHTEQzAAAAAEqAKR8AAAAEZ0FNQQAAsY8L/GEFAAAABmJLR0QA/wD/AP+gvaeTAAAAMklEQVR4nGMwIBEwAPFJWQVMlLHvLSYayRqcdmNBD8tFMNFI1kBa4vMnETD8Z/hPEgIAvqs9dJhBcSIAAAAASUVORK5CYII==");
					}
					
					#curve {
						padding-top : 10px;
					}
					
					select, button, input {
						icon-top : 2px;
						width : 70px;
						height : 11px;
						padding-top : 2px;
					}
					
					input {
						height : 13px;
						padding-top : 2px;
					}
					
					.curve .val {
						display : none;
					}
					
					.m_const .v_min, .m_linear .v_min, .m_pow .v_min, .m_random .v_min {
						display : block;
					}

					.m_linear .v_max, .m_pow .v_max, .m_random .v_max {
						display : block;
					}
					
					.m_pow .v_pow {
						display : block;
					}
					
				</style>
				<div class="main panel">
					<div class="col">
						<div class="line">
							<checkbox checked="${state.loop}" onchange="api.s.loop = this.checked"/> <span>Loop</span>
						</div>
						<div class="line">
							<span>Life</span> <value value="${state.globalLife}" onchange="api.s.globalLife = this.value"/>
						</div>
						<div class="line">
							<button class="ic" value="Speed" onclick="api.editCurve(\'globalSpeed\')"/>
						</div>
						<div class="line">
							<button class="ic" value="Size" onclick="api.editCurve(\'globalSize\')"/>
						</div>
						<select onchange="api.s.blendMode = api.blendModes[api.parseInt(this.value)]">
							<option value="0" checked="${state.blendMode == Add}">Additive</option>
							<option value="1" checked="${state.blendMode == Alpha}">Alpha</option>
							<option value="2" checked="${state.blendMode == SoftAdd}">Soft Add</option>
						</select>
					</div>
					<div class="col">
						<button class="ic" value="Emit Rate" onclick="api.editCurve(\'emitRate\')"/>
						<div class="line">
							<span>Bursts</span> <select/> <span>TODO</span>
						</div>
						<div class="line">
							<span>Max Parts</span> <value value="${state.maxParts}" increment="1" onchange="api.s.maxParts = this.value"/>
						</div>
						<div class="line" id="shape">
							<select onchange="api.setCurShape(api.parseInt(this.value))">
								<option value="0" checked="${state.shape.match(SDir(_))}">Direction</option>
								<option value="1" checked="${state.shape.match(SSphere(_))}">Sphere</option>
								<option value="2" checked="${state.shape.match(SSector(_))}">Sector</option>
							</select>
							<div class="val">
								<span>Size</span> <value value="${
									switch( state.shape ) {
									case SSphere(r), SSector(r,_): r;
									case SDir(x, y, z): Math.sqrt(x * x + y * y + z * z);
									case SCustom(_): 0.;
									}} " onchange="api.setShapeProp(\'size\', this.value)"/>
							</div>
							<div class="val">
								<span>Angle</span> <value value="${
									(switch( state.shape ) {
									case SSector(_,a): a;
									default: 0.;
								}) * 180 / Math.PI} " onchange="api.setShapeProp(\'angle\', this.value)"/>
							</div>
						</div>
						<div class="line">
							<checkbox checked="${state.emitFromShell}" onchange="api.s.emitFromShell = this.checked"/> <span>Emit from Shell</span>
						</div>
						<div class="line">
							<checkbox checked="${state.randomDir}" onchange="api.s.randomDir = this.checked"/> <span>Random Dir</span>
						</div>
					</div>
					<div class="col buttons">
						<button class="ic" value="Life" onclick="api.editCurve(\'life\')"/>
						<button class="ic" value="Size" onclick="api.editCurve(\'size\')"/>
						<button class="ic" value="Rotation" onclick="api.editCurve(\'rotation\')"/>
						<button class="ic" value="Speed" onclick="api.editCurve(\'speed\')"/>
						<button class="ic" value="Gravity" onclick="api.editCurve(\'gravity\')"/>
						<button class="icol" value="Color" onclick="api.editColors()"/>
					</div>
					<div style="layout:dock;width:200px">
						<div class="col" style="dock:bottom">
							<div class="line">
								<span>Loop Time</span> <value value="${props.startTime}" onchange="api.props.startTime = this.value"/>
							</div>
							<div class="line">
								<checkbox checked="${props.pause}" onchange="api.props.pause = this.checked"/> <span>Pause</span>
							</div>
							<div class="line">
								<button value="Start" onclick="api.reset()"/>
							</div>
							<label id="stats"/>
						</div>
					</div>
				</div>
				<div class="curve panel">
					<div class="line">
						<select onchange="api.setCurveMode(api.parseInt(this.value))">
							${{
								var str = "";
								for( i in 0...CURVES.length )
									str += '<option value="$i" checked="${i == curve.mode}">${CURVES[i].name}</option>';
								str;
							}}
						</select>
						<div class="val v_min">
							<span>Min</span> <value value="${curve.min}" increment="${curve.incr}" onchange="api.curve.min = this.value; api.updateCurve()"/>
						</div>
						<div class="val v_max">
							<span>Max</span> <value value="${curve.max}" increment="${curve.incr}" onchange="api.curve.max = this.value; api.updateCurve()"/>
						</div>
						<div class="val v_pow">
							<span>Pow</span> <value value="${curve.pow}" increment="0.01" onchange="api.curve.pow = this.value; api.updateCurve()"/>
						</div>
					</div>
					<div id="curve">
					</div>
				</div>
			</body>
		',{
			s : state,
			parseInt : Std.parseInt,
			parseFloat : Std.parseFloat,
			blendModes : Type.allEnums(BlendMode),
			reset : emit.reset,
			props : props,
			curve : curve,
			setCurveMode : setCurveMode,
			updateCurve : updateCurve,
			editCurve : editCurve,
			setCurShape : setCurShape,
			setShapeProp : setShapeProp,
			editColors : editColors,
		});
		addChildAt(ui,0);
		stats = cast ui.getElementById("stats");
		var c = ui.getElementById("curve");
		c.addChild(new h2d.Bitmap(curveBG));
		c.addChild(new h2d.Bitmap(curveTexture));
		setCurveMode(curve.mode);
	}
	
	function editColors() {
		if( grad != null ) {
			grad.remove();
			grad = null;
			return;
		}
		grad = new h2d.comp.GradientEditor(false, this);
		grad.setKeys(state.colors == null ? [ { x : 0., value : 0xFFFFFF }, { x : 1., value : 0xFFFFFF } ] : [for( c in state.colors ) { x : c.time, value : c.color } ]);
		grad.onChange = function(keys) {
			state.colors = [for( k in keys ) { time : k.x, color : k.value & 0xFFFFFF } ];
			var found = false;
			for( s in state.colors )
				if( s.color != 0xFFFFFF ) {
					found = true;
					break;
				}
			if( !found ) state.colors = null;
		};
	}
	
	function editCurve( name : String ) {
		var old : Value = Reflect.field(state, name);
		var v = old;
		if( v == null )
			switch( name ) {
			default:
				v = VLinear(0,1);
			}
		initCurve(v);
		curve.name = name;
		switch( name ) {
		case "emitRate":
			curve.incr = 1;
		default:
			curve.incr = 0.01;
		}
		rebuildCurve();
		buildUI();
	}
	
	function init() {
		var bg = new hxd.BitmapData(300, 110);
		bg.clear(0xFF202020);
		for( h in [0, bg.height >> 1, bg.height - 1] )
			bg.line(0, h, bg.width - 1, h, 0xFF101010);
		for( h in [bg.height * 0.25, bg.height * 0.75] ) {
			var h = Math.round(h);
			bg.line(0, h, bg.width - 1, h, 0xFF191919);
		}
		curveBG = h2d.Tile.fromBitmap(bg);
		bg.dispose();
		curveTexture = 	h2d.Tile.fromTexture(h3d.Engine.getCurrent().mem.allocTexture(512, 512)).sub(0, 0, curveBG.width, curveBG.height);
	}
	
	function rebuildCurve() {
		var bmp = new hxd.BitmapData(512, 512);
		var width = curveTexture.width, height = curveTexture.height;
		var scaleY = 1 / (curve.incr * 100);
		inline function posY(y:Float) {
			return Std.int((1 - y * scaleY) * 0.5 * height);
		}
		switch( curve.value ) {
		case VRandom(start, len):
			var y0 = posY(start), y1 = posY(start + len);
			bmp.fill(h2d.col.Bounds.fromValues(0, Math.min(y0,y1), width, Math.abs(y1 - y0)),0x40FF0000);
			bmp.line(0, y0, width - 1, y0, 0xFFFF0000);
			bmp.line(0, y1, width - 1, y1, 0xFFFF0000);
		default:
			for( x in 0...width ) {
				var px = x / (width - 1);
				var py = state.eval(curve.value, px, Math.random());
				bmp.setPixel(x, posY(py), 0xFFFF0000);
			}
		}
		curveTexture.getTexture().uploadBitmap(bmp);
		bmp.dispose();
	}
	
	function initCurve( v : Value ) {
		var c = curve;
		c.value = v;
		c.mode = v.getIndex();
		switch( v ) {
		case VConst(v):
			c.min = c.max = v;
		case VLinear(min, len):
			c.min = min;
			c.max = min + len;
		case VPow(min, len, pow):
			c.min = min;
			c.max = min + len;
			c.pow = pow;
		case VRandom(a, b):
			c.min = a;
			c.max = b;
		case VCustom(_):
			throw "assert";
		}
	}
	
	function setCurShape( mode : Int ) {
		state.shape = switch( mode ) {
		case 0: SDir(0, 0, 1);
		case 1: SSphere(1);
		case 2: SSector(1,Math.PI/4);
		default: throw "Unknown shape #" + mode;
		}
		buildUI();
	}
	
	function setShapeProp( prop : String, v : Float ) {
		if( prop == "angle" )
			v = v * Math.PI / 180;
		switch( [state.shape, prop] ) {
		case [SSphere(_), "size"]:
			state.shape = SSphere(v);
		case [SSector(_,a), "size"]:
			state.shape = SSector(v,a);
		case [SSector(s,_), "angle"]:
			state.shape = SSector(s,v);
		case [SDir(_, _, _), "size"]:
			state.shape = SDir(0,0,v);
		default:
		}
	}
	
	function setCurveMode( mode : Int ) {
		var cm = ui.getElementById("curve").getParent();
		cm.removeClass("m_" + CURVES[curve.mode].name.toLowerCase());
		curve.mode = mode;
		cm.addClass("m_" + CURVES[curve.mode].name.toLowerCase());
		updateCurve();
	}
	
	function updateCurve() {
		curve.value = CURVES[curve.mode].f(curve);
		if( curve.name != null ) Reflect.setField(state, curve.name, curve.value);
		rebuildCurve();
	}

	function setTexture( t : hxd.BitmapData ) {
		if( state.texture != null )
			state.texture.dispose();
		state.texture = h3d.mat.Texture.fromBitmap(t);
	}
	
	override function sync( ctx : h3d.scene.RenderContext ) {
		// if resized, let's reflow our ui
		if( ctx.engine.width != width || ctx.engine.height != height ) {
			ui.refresh();
			width = ctx.engine.width;
			height = ctx.engine.height;
		}
		if( cachedMode != state.blendMode && state.textureName == null ) {
			cachedMode = state.blendMode;
			var t = switch( state.blendMode ) {
			case Add, SoftAdd: new DefaultPart(0, 0);
			case Alpha: new DefaultPartAlpha(0, 0);
			};
			setTexture(hxd.BitmapData.fromNative(t));
			t.dispose();
		}
		var old = state.texture;
		state.texture = null;
		var s = haxe.Serializer.run(state);
		state.texture = old;
		if( s != curState ) {
			curState = s;
			emit.setState(state);
		}
		emit.pause = props.pause;
		var pcount = emit.count;
		if( stats != null ) stats.text = hxd.Math.fmt(emit.time) + " s\n" + pcount + " p\n" + hxd.Math.fmt(ctx.engine.fps) + " fps" + ("\n"+getScene().getSpritesCount());
		if( !state.loop && pcount == 0 && emit.time > 1 ) {
			if( lastPartSeen == null )
				lastPartSeen = emit.time;
			else if( emit.time - lastPartSeen > 0.5 ) {
				emit.reset();
				if( Math.isNaN(props.startTime) ) props.startTime = 0;
				var dt = 1 / 60;
				var t = props.startTime;
				while( t > dt ) {
					emit.update(dt);
					t -= dt;
				}
				if( t > 0 )
					emit.update(t);
			}
		} else
			lastPartSeen = null;
			
		if( grad != null ) {
			grad.x = width - 451;
			grad.y = height - 380;
			grad.colorPicker.x = grad.boxWidth - 180;
			grad.colorPicker.y = -321;
		}
			
		super.sync(ctx);
	}
	
}