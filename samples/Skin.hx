import h3d.scene.*;

class Skin extends SampleApp {

	var cache : h3d.prim.ModelCache;

	override function init() {
		cache = new h3d.prim.ModelCache();

		var obj = cache.loadModel(hxd.Res.Model);
		obj.scale(0.1);
		s3d.addChild(obj);
		s3d.camera.pos.set( -3, -5, 3);
		s3d.camera.target.z += 1;

		obj.playAnimation(cache.loadAnimation(hxd.Res.Model));

		// add lights and setup materials
		var dir = new DirLight(new h3d.Vector( -1, 3, -10), s3d);
		for( m in obj.getMaterials() ) {
			var t = m.mainPass.getShader(h3d.shader.Texture);
			if( t != null ) t.killAlpha = true;
			m.mainPass.culling = None;
			m.getPass("shadow").culling = None;
		}
		s3d.lightSystem.ambientLight.set(0.4, 0.4, 0.4);

		var shadow = cast(s3d.renderer.getPass("shadow"), h3d.pass.ShadowMap);
		shadow.power = 20;
		shadow.color.setColor(0x301030);
		dir.enableSpecular = true;

		new h3d.scene.CameraController(s3d).loadFromCamera();
	}

	static function main() {
		hxd.Res.initEmbed();
		new Skin();
	}

}
