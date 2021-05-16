using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

namespace Water.Data
{
    [CustomEditor(typeof(WaterSurfaceData))]
    public class WaterSurfaceDataEditor : Editor
    {

        [SerializeField]
        ReorderableList waveList;

        private void OnEnable()
        {
            var standardHeight = EditorGUIUtility.singleLineHeight;
            var standardLine = standardHeight + EditorGUIUtility.standardVerticalSpacing;
            waveList = new ReorderableList(serializedObject, serializedObject.FindProperty("_Waves"), true, true, true, true);

            waveList.drawElementCallback = (Rect rect, int index, bool isActive, bool isFocused) =>
            {
                var element = waveList.serializedProperty.GetArrayElementAtIndex(index);
                rect.y += 2;

                var preWidth = EditorGUIUtility.labelWidth;

                EditorGUIUtility.labelWidth = rect.width * 0.2f;
                Rect ampRect = new Rect(rect.x, rect.y + standardLine, rect.width * 0.5f, standardHeight);
                var waveAmplitude = element.FindPropertyRelative("amplitude");
                waveAmplitude.floatValue = EditorGUI.Slider(ampRect, "Swell Height", waveAmplitude.floatValue, 0.1f, 30.0f);

                Rect lengthRect = new Rect(rect.x + ampRect.width, rect.y + standardLine, rect.width * 0.5f, standardHeight);
                var waveLen = element.FindPropertyRelative("wavelength");
                waveLen.floatValue = EditorGUI.Slider(lengthRect, "Wavelength", waveLen.floatValue, 1.0f, 200f);
                EditorGUIUtility.labelWidth = preWidth;

                Rect dirToggleRect = new Rect(rect.x, rect.y + 2 + standardLine * 2, rect.width * 0.5f, standardHeight);
                Rect omniToggleRect = new Rect(rect.x + rect.width * 0.5f, dirToggleRect.y, rect.width * 0.5f, standardHeight);
                Rect containerRect = new Rect(rect.x, dirToggleRect.y + 1, rect.width, standardLine * 3.2f);

                var waveType = element.FindPropertyRelative("omniDir");
                var wTypeBool = (int)waveType.floatValue == 1 ? true : false;
                GUI.Box(containerRect, "", EditorStyles.helpBox);
                wTypeBool = !GUI.Toggle(dirToggleRect, !wTypeBool, "Directional", EditorStyles.miniButtonLeft);
                wTypeBool = GUI.Toggle(omniToggleRect, wTypeBool, "Omni-directional", EditorStyles.miniButtonRight);
                waveType.floatValue = wTypeBool ? 1 : 0;

                Rect dirRect = new Rect(rect.x + 4, dirToggleRect.y + standardLine, rect.width - 8, standardHeight);
                Rect buttonRect = new Rect(rect.x + 4, dirRect.y + standardLine + 2, rect.width - 8, standardHeight);

                if (!wTypeBool)
                {
                    //Directional
                    var waveDir = element.FindPropertyRelative("direction");
                    waveDir.floatValue = EditorGUI.Slider(dirRect, "FaceDirection", waveDir.floatValue, -180.0f, 180.0f);
                    if (GUI.Button(buttonRect, "Align Camera"))
                        waveDir.floatValue = CameraRelativeDir();
                }
                else
                {
                    //Omni-Directional
                    EditorGUIUtility.wideMode = true;
                    var waveOrig = element.FindPropertyRelative("origin");

                    waveOrig.vector2Value = EditorGUI.Vector2Field(dirRect, "Point of Origin", waveOrig.vector2Value);
                    if (GUI.Button(buttonRect, "Project Origin from Scene Camera"))
                        waveOrig.vector2Value = CameraRelativeOrigin(waveOrig.vector2Value);
                }

            };

            waveList.onCanRemoveCallback = (ReorderableList list) =>
            {
                return list.count > 1;
            };

            waveList.onRemoveCallback = (ReorderableList list) =>
            {
                if (EditorUtility.DisplayDialog("Delete wave", "Delete it?", "Yes", "No"))
                {
                    ReorderableList.defaultBehaviours.DoRemoveButton(list);
                }
            };

            waveList.drawHeaderCallback = (Rect rect) =>
            {
                EditorGUI.LabelField(rect, "WaveList");
            };

            waveList.elementHeightCallback = (index) =>
            {
                var elementHeight = standardLine * 6;
                return elementHeight;
            };

            waveList.onAddCallback=(ReorderableList list)=>{
                waveList.serializedProperty.arraySize++;

                var newElement=list.serializedProperty.GetArrayElementAtIndex(waveList.serializedProperty.arraySize-1);
                var amplitude=newElement.FindPropertyRelative(nameof(Wave.amplitude));
                var wavelength=newElement.FindPropertyRelative(nameof(Wave.wavelength));
                var omniDir=newElement.FindPropertyRelative(nameof(Wave.omniDir));
                var direction=newElement.FindPropertyRelative(nameof(Wave.direction));
                var origin=newElement.FindPropertyRelative(nameof(Wave.origin));

                amplitude.floatValue=0.1f;
                wavelength.floatValue=1.0f;
                omniDir.floatValue=1;
                direction.floatValue=0f;
                origin.vector2Value=new Vector2(0,0);

            };
        }

        private void OnValidate()
        {
            var init = serializedObject.FindProperty("_init");
            if (init?.boolValue == false)
                Setup();



        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUILayout.LabelField("Visual Settings", EditorStyles.boldLabel);
            EditorGUI.indentLevel += 1;

            var maxDepth = serializedObject.FindProperty("_waterMaxVisibility");
            EditorGUILayout.Slider(maxDepth, 3, 300, new GUIContent("Maximum Visibility", "Water transparency/visibility"));


            //ColorControls
            DoSmallHeader("Color Controls");
            var absorptionRamp = serializedObject.FindProperty("_absorptionRamp");
            EditorGUILayout.PropertyField(absorptionRamp, new GUIContent("Absorption", "Color of Absorption"), true, null);

            var scatterRamp = serializedObject.FindProperty("_scatterRamp");
            EditorGUILayout.PropertyField(scatterRamp, new GUIContent("Scatter", "Color of Scatter"), true, null);

            //Foam Ramps
            DoSmallHeader("Surface Foam");
            var foamSettings = serializedObject.FindProperty("_foamSettings");
            var foamType = foamSettings.FindPropertyRelative("foamType");
            foamType.intValue = GUILayout.Toolbar(foamType.intValue, foamTypeOptions);

            EditorGUILayout.Space();

            switch (foamType.intValue)
            {
                case 0:
                    {
                        EditorGUILayout.HelpBox("Auto", MessageType.Info);
                    }
                    break;
                case 1:
                    {//simple
                        EditorGUILayout.BeginHorizontal();
                        DoInlineLabel("Foam profile", "control foam propagation,X-WaveHeight,Y-FoamOpacity", 50f);
                        var basicFoam = foamSettings.FindPropertyRelative("basicFoam");
                        basicFoam.animationCurveValue = EditorGUILayout.CurveField(basicFoam.animationCurveValue, Color.white, new Rect(Vector2.zero, Vector2.one));
                        EditorGUILayout.EndHorizontal();
                    }
                    break;
                case 2:
                    {//Density
                        EditorGUILayout.BeginHorizontal();
                        DoInlineLabel("Foam profiles", "control Lite,Medium,Dense foam propagation,X-wave height,Y-foam opacity", 50f);

                        var liteFoam = foamSettings.FindPropertyRelative("liteFoam");
                        liteFoam.animationCurveValue = EditorGUILayout.CurveField(liteFoam.animationCurveValue, new Color(0.5f, 0.75f, 1f, 1f), new Rect(Vector2.zero, Vector2.one));

                        var mediumFoam = foamSettings.FindPropertyRelative("mediumFoam");
                        mediumFoam.animationCurveValue = EditorGUILayout.CurveField(mediumFoam.animationCurveValue, new Color(0f, 0.5f, 1f, 1f), new Rect(Vector2.zero, Vector2.one));

                        var denseFoam = foamSettings.FindPropertyRelative("denseFoam");
                        denseFoam.animationCurveValue = EditorGUILayout.CurveField(denseFoam.animationCurveValue, Color.blue, new Rect(Vector2.zero, Vector2.one));

                        EditorGUILayout.EndHorizontal();
                    }
                    break;
            }

            DoSmallHeader("Wave Setting");
            var customWaves = serializedObject.FindProperty("_customWaves");
            var intVal = customWaves.boolValue ? 1 : 0;
            intVal = GUILayout.Toolbar(intVal, waveTypeOptions);
            customWaves.boolValue = intVal == 1 ? true : false;

            EditorGUILayout.Space();
            switch (intVal)
            {
                case 0:
                    {
                        var basicSettings = serializedObject.FindProperty("_basicWaveSettings");
                        var autoCount = basicSettings.FindPropertyRelative("numWaves");
                        EditorGUILayout.IntSlider(autoCount, 1, 10, new GUIContent("Wave Count", "Num of waves the auto create"), null);

                        var amplitude = basicSettings.FindPropertyRelative("amplitude");
                        EditorGUILayout.Slider(amplitude, 0.1f, 30.0f, new GUIContent("Amplitude", "AvgSwelHeight"), null);

                        var wavelength = basicSettings.FindPropertyRelative("wavelength");
                        EditorGUILayout.Slider(wavelength, 1.0f, 200.0f, new GUIContent("wavelength", "AvgWaveLength"), null);

                        EditorGUILayout.BeginHorizontal();
                        var direction = basicSettings.FindPropertyRelative("direction");
                        EditorGUILayout.Slider(direction, -180.0f, 180.0f, new GUIContent("direction", "Wind Direction"), null);
                        if (GUILayout.Button(new GUIContent("Align to scene camera", "This aligns the wave direction to the current scene view camera facing direction")))
                            direction.floatValue = CameraRelativeDir();
                        EditorGUILayout.EndHorizontal();


                        EditorGUILayout.BeginHorizontal();
                        var randSeed = serializedObject.FindProperty("randomSeed");
                        randSeed.intValue = EditorGUILayout.IntField(new GUIContent("Random Seed", "Seed control wave generate"), randSeed.intValue);

                        if (GUILayout.Button("Randomize Waves"))
                        {
                            randSeed.intValue = System.DateTime.Now.Millisecond * 100 - System.DateTime.Now.Millisecond;
                        }
                        EditorGUILayout.EndHorizontal();
                    }
                    break;

                case 1:
                    {
                        EditorGUI.indentLevel -= 1;

                        waveList.DoLayoutList();
                    }
                    break;

            }

            EditorUtility.SetDirty(this);
            serializedObject.ApplyModifiedProperties();
        }

        void DoSmallHeader(string header)
        {
            EditorGUI.indentLevel -= 1;
            EditorGUILayout.LabelField(header, EditorStyles.miniBoldLabel);
            EditorGUI.indentLevel += 1;
        }

        void DoInlineLabel(string label, string tips, float width)
        {
            var perWidth = EditorGUIUtility.labelWidth;

            EditorGUIUtility.labelWidth = width;
            EditorGUILayout.LabelField(new GUIContent(label, tips));

            EditorGUIUtility.labelWidth = perWidth;
        }

        void Setup()
        {
            //修改对象
            WaterSurfaceData data = (WaterSurfaceData)target;
            data._init = true;
            data._absorptionRamp = DefaultAbsorptionGrad();
            data._scatterRamp = DefaultScatterGrad();
            EditorUtility.SetDirty(data);
        }

        Gradient DefaultAbsorptionGrad()
        {
            Gradient gradient = new Gradient();
            GradientColorKey[] GCK = new GradientColorKey[5];

            GradientAlphaKey[] GAK = new GradientAlphaKey[1];

            GAK[0].alpha = 1;
            GAK[0].time = 0;

            GCK[0].color = Color.white; GCK[0].time = 0f;

            GCK[1].color = new Color(0.22f, 0.87f, 0.87f); GCK[1].time = 0.082f;

            GCK[2].color = new Color(0f, 0.47f, 0.49f); GCK[2].time = 0.318f;

            GCK[3].color = new Color(0f, 0.275f, 0.44f); GCK[3].time = 0.665f;

            GCK[4].color = Color.black; GCK[4].time = 1f;

            gradient.SetKeys(GCK, GAK);
            return gradient;
        }

        Gradient DefaultScatterGrad()
        {
            Gradient gradient = new Gradient();
            GradientColorKey[] GCK = new GradientColorKey[4];
            GradientAlphaKey[] GAK = new GradientAlphaKey[1];

            GAK[0].alpha = 1;
            GAK[0].time = 0;

            GCK[0].color = Color.black; GCK[0].time = 0f;

            GCK[1].color = new Color(0.08f, 0.41f, 0.34f); GCK[1].time = 0.15f;

            GCK[2].color = new Color(0.13f, 0.55f, 0.45f); GCK[2].time = 0.42f;

            GCK[3].color = new Color(0.21f, 0.62f, 0.6f); GCK[3].time = 1f;

            gradient.SetKeys(GCK, GAK);

            return gradient;
        }

        float CameraRelativeDir()
        {
            float degrees = 0;

            Vector3 camFwd = UnityEditor.SceneView.lastActiveSceneView.camera.transform.forward;
            camFwd.y = 0.0f;
            camFwd.Normalize();

            float _ForwardDotCamFwd = Vector3.Dot(-Vector3.forward, camFwd);
            degrees = Mathf.LerpUnclamped(90.0f, 180.0f, _ForwardDotCamFwd);
            if (camFwd.x < 0)
                degrees *= -1f;
            return Mathf.RoundToInt(degrees * 1000) / 1000;
        }

        Vector2 CameraRelativeOrigin(Vector2 origin)
        {
            Camera sceneCam = UnityEditor.SceneView.lastActiveSceneView.camera;

            float angle = 90f - Vector3.Angle(sceneCam.transform.forward, Vector3.down);
            if (angle > 0.1f)
            {
                Vector3 intersect = Vector2.zero;
                float hypot = (sceneCam.transform.position.y) * (1 / Mathf.Sin(Mathf.Deg2Rad * angle));
                Vector3 forward = sceneCam.transform.forward * hypot;

                intersect = forward + sceneCam.transform.position;
                return new Vector2(intersect.x, intersect.z);
            }
            else
                return origin;

        }

        string[] waveTypeOptions = { "Auto", "Customized" };
        string[] foamTypeOptions = { "Automatic", "Simple Curve", "Density Curves" };
    }
}


