using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Water.Data;

namespace Water {
    [CustomEditor(typeof(Water))]
    public class WaterEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            Water water = (Water)target;

            var waterSettingsData = serializedObject.FindProperty("waterSettingData");
            EditorGUILayout.PropertyField(waterSettingsData,true);
            if (waterSettingsData.objectReferenceValue != null)
                CreateEditor((WaterSettingData)waterSettingsData.objectReferenceValue).OnInspectorGUI();

            var waterSurfaceData = serializedObject.FindProperty("waterSurfaceData");
            EditorGUILayout.PropertyField(waterSurfaceData, true);
            if (waterSurfaceData.objectReferenceValue != null)
                CreateEditor((WaterSurfaceData)waterSurfaceData.objectReferenceValue).OnInspectorGUI();
            serializedObject.ApplyModifiedProperties();
            if (GUI.changed)
                water.Init();
            base.OnInspectorGUI();
        }
    }
}

