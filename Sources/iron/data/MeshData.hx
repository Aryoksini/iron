package iron.data;

import kha.graphics4.VertexBuffer;
import kha.graphics4.Usage;
import kha.graphics4.VertexStructure;
import iron.data.SceneFormat;

class MeshData extends Data {

	public var name:String;
	public var raw:TMeshData;
	public var mesh:Mesh;

#if WITH_CPU_SKIN
	public static inline var ForceCpuSkinning = true;
#else
	public static inline var ForceCpuSkinning = false;
#end

	public var isSkinned:Bool;
	public var bones:Array<TObj> = [];

	public function new(raw:TMeshData) {
		super();

		this.raw = raw;
		this.name = raw.name;

		// Mesh data
		var indices:Array<Array<Int>> = [];
		var materialIndices:Array<Int> = [];
		for (ind in raw.mesh.index_arrays) {
			indices.push(ind.values);
			materialIndices.push(ind.material);
		}

		var paVA = getVertexArray("position");
		var pa = paVA != null ? paVA.values : null;
		
		var naVA = getVertexArray("normal");
		var na = naVA != null ? naVA.values : null; 

		var uvaVA = getVertexArray("texcoord");
		var uva = uvaVA != null ? uvaVA.values : null;

		var caVA = getVertexArray("color");
		var ca = caVA != null ? caVA.values : null;

		// Normal mapping
		var tanaVA = getVertexArray("tangent");
		var tana = tanaVA != null ? tanaVA.values : null;

		// Skinning
		isSkinned = raw.mesh.skin != null ? true : false;

		// Usage, also used for instanced data
		var parsedUsage = Usage.StaticUsage;
		if (raw.mesh.static_usage != null && raw.mesh.static_usage == false) parsedUsage = Usage.DynamicUsage;
		var usage = (isSkinned && ForceCpuSkinning) ? Usage.DynamicUsage : parsedUsage;

		var bonea:Array<Float> = null; // Store bone indices and weights per vertex
		var weighta:Array<Float> = null;
		if (isSkinned && !ForceCpuSkinning) {
			bonea = [];
			weighta = [];

			var index = 0;
			for (i in 0...Std.int(pa.length / 3)) {
				var boneCount = raw.mesh.skin.bone_count_array[i];
				for (j in index...(index + boneCount)) {
					bonea.push(raw.mesh.skin.bone_index_array[j]);
					weighta.push(raw.mesh.skin.bone_weight_array[j]);
				}
				// Fill unused weights
				for (j in boneCount...4) {
					bonea.push(0);
					weighta.push(0);
				}
				index += boneCount;
			}
		}
		
		// Make vertex buffers
		mesh = new Mesh(indices, materialIndices, pa, na, uva, ca, tana, bonea, weighta, usage);

		// Instanced
		if (raw.mesh.instance_offsets != null) {
			mesh.setupInstanced(raw.mesh.instance_offsets, usage);
		}
	}

	public function delete() {
		mesh.delete();
	}

	public static function parse(name:String, id:String, boneObjects:Array<TObj> = null):MeshData {
		var format:TSceneFormat = Data.getSceneRaw(name);
		var raw:TMeshData = Data.getMeshRawByName(format.mesh_datas, id);
		if (raw == null) {
			trace('Mesh data "$id" not found!');
			return null;
		}

		var dat = new MeshData(raw);

		// Skinned
		if (raw.mesh.skin != null) {
			// TODO: check !ForceCpuSkinning
			var objects = boneObjects != null ? boneObjects : format.objects;
			for (o in objects) {
				setParents(o);
			}
			traverseObjects(objects, function(object:TObj) {
				if (object.type == "bone_object") {
					dat.bones.push(object);
				}
			});

			dat.mesh.initSkinTransform(raw.mesh.skin.transform.values);
			dat.mesh.skinBoneCounts = raw.mesh.skin.bone_count_array;
			dat.mesh.skinBoneIndices = raw.mesh.skin.bone_index_array;
			dat.mesh.skinBoneWeights = raw.mesh.skin.bone_weight_array;
			dat.mesh.skeletonBoneRefs = raw.mesh.skin.skeleton.bone_ref_array;
			dat.mesh.initSkeletonBones(dat.bones);
			dat.mesh.initSkeletonTransforms(raw.mesh.skin.skeleton.transforms);
		}
		return dat;
	}

	static function setParents(object:TObj) {
		if (object.children == null) return;
		for (o in object.children) {
			o.parent = object;
			setParents(o);
		}
	}
	static function traverseObjects(objects:Array<TObj>, callback:TObj->Void) {
		for (i in 0...objects.length) {
			traverseObjectsStep(objects[i], callback);
		}
	}
	static function traverseObjectsStep(object:TObj, callback:TObj->Void) {
		callback(object);
		if (object.children == null) return;
		for (i in 0...object.children.length) {
			traverseObjectsStep(object.children[i], callback);
		}
	}

	function getVertexArray(attrib:String):TVertexArray {
		for (va in raw.mesh.vertex_arrays) {
			if (va.attrib == attrib) {
				return va;
			}
		}
		return null;
	}
}
