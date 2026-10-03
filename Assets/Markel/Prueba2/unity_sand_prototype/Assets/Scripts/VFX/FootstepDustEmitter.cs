using UnityEngine;

[DisallowMultipleComponent]
public class FootstepDustEmitter : MonoBehaviour
{
    [Header("References")]
    public ParticleSystem particleSystem;

    [Header("Emission")]
    [Range(1, 30)] public int minParticles = 4;
    [Range(1, 30)] public int maxParticles = 8;
    [Min(0f)] public float lifetimeMin = 0.12f;
    [Min(0f)] public float lifetimeMax = 0.35f;
    [Min(0f)] public float sizeMin = 0.03f;
    [Min(0f)] public float sizeMax = 0.08f;

    [Header("Motion")]
    [Min(0f)] public float outwardSpeed = 0.35f;
    [Min(0f)] public float upwardSpeed = 0.5f;
    [Min(0f)] public float randomSpeed = 0.25f;

    [Header("Color")]
    public Color dustColorMin = new Color(0.72f, 0.42f, 0.22f, 0.35f);
    public Color dustColorMax = new Color(1f, 0.66f, 0.36f, 0.6f);

    public void EmitAt(Vector3 position, Vector3 forward, Vector3 normal)
    {
        if (particleSystem == null)
            return;

        int count = Random.Range(minParticles, maxParticles + 1);
        Vector3 planarForward = Vector3.ProjectOnPlane(forward, normal);

        if (planarForward.sqrMagnitude < 0.001f)
            planarForward = Vector3.forward;

        planarForward.Normalize();

        for (int i = 0; i < count; i++)
        {
            Vector2 circle = Random.insideUnitCircle;
            Vector3 tangentOffset = circle.x * Vector3.Cross(normal, planarForward);
            Vector3 planarOffset = planarForward * circle.y;

            Vector3 velocity =
                (tangentOffset + planarOffset) * randomSpeed +
                planarForward * outwardSpeed +
                normal * upwardSpeed * Random.Range(0.6f, 1f);

            ParticleSystem.EmitParams emit = new ParticleSystem.EmitParams
            {
                position = position + Random.insideUnitSphere * 0.025f,
                velocity = velocity,
                startLifetime = Random.Range(lifetimeMin, lifetimeMax),
                startSize = Random.Range(sizeMin, sizeMax),
                startColor = Color.Lerp(
                    dustColorMin,
                    dustColorMax,
                    Random.value
                ),
                rotation3D = new Vector3(
                    Random.Range(0f, 360f),
                    Random.Range(0f, 360f),
                    Random.Range(0f, 360f)
                )
            };

            particleSystem.Emit(emit, 1);
        }
    }
}
