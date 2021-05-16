using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ArkUI : MonoBehaviour
{
    public Vector2 range=new Vector2(4f,3f);
    Quaternion mStart;
    Vector2 mRot=Vector2.zero;
    // Start is called before the first frame update
    void Start()
    {
        mStart=transform.localRotation;
    }

    private void TransformTrans(){
        Vector3 pos=Input.mousePosition;
        float h_width=Screen.width/2;
        float h_height=Screen.height/2;

        float x=Mathf.Clamp((pos.x-h_width)/h_width,-1,1);
        float y=Mathf.Clamp((pos.y-h_height)/h_height,-1,1);
        mRot=Vector2.Lerp(mRot,new Vector2(y,x),Time.deltaTime);
        transform.localRotation=mStart*Quaternion.Euler(-mRot.x*range.x,mRot.y*range.y,0);

    }


    // Update is called once per frame
    void FixedUpdate()
    {
        TransformTrans();
    }
}
