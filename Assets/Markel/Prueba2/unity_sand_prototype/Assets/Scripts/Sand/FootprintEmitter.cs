using UnityEngine;

[DisallowMultipleComponent]
public class FootprintEmitter : MonoBehaviour
{
    [Header("References")]
    public SandInteractionManager sandInteraction;
    public Transform playerRoot;
    public Transform leftFoot;
    public Transform rightFoot;
    public FootstepDustEmitter dustEmitter;

    [Header("Movement")]
    [Min(0.1f)] public float stepDistance = 1.4f;
    [Min(0f)] public float minimumMoveSpeed = 0.35f;

    [Header("Ground Check")]
    public LayerMask groundMask = ~0;
    [Min(0.05f)] public float rayStartHeight = 0.5f;
    [Min(0.1f)] public float rayDistance = 2f;

    [Header("Footprint")]
    public Vector2 footprintSize = new Vector2(0.34f, 0.65f);
    [Range(0f, 1f)] public float footprintStrength = 0.8f;

    private Vector3 previousRootPosition;
    private float distanceAccumulator;
    private bool nextLeft = true;

    private void Awake()
    {
        if (playerRoot == null)
            playerRoot = transform;

        previousRootPosition = playerRoot.position;
    }

    private void Update()
    {
        if (sandInteraction == null || playerRoot == null)
            return;

        Vector3 current = playerRoot.position;
        Vector3 delta = current - previousRootPosition;
        previousRootPosition = current;

        Vector3 horizontalDelta = Vector3.ProjectOnPlane(delta, Vector3.up);
        float distance = horizontalDelta.magnitude;
        float speed = distance / Mathf.Max(Time.deltaTime, 0.0001f);

        if (speed < minimumMoveSpeed || distance <= 0f)
            return;

        distanceAccumulator += distance;

        while (distanceAccumulator >= stepDistance)
        {
            distanceAccumulator -= stepDistance;
            EmitStep();
        }
    }

    private void EmitStep()
    {
        Transform foot = GetNextFoot();
        Vector3 origin = foot != null
            ? foot.position + Vector3.up * rayStartHeight
            : playerRoot.position + Vector3.up * rayStartHeight;

        if (!Physics.Raycast(
                origin,
                Vector3.down,
                out RaycastHit hit,
                rayDistance,
                groundMask,
                QueryTriggerInteraction.Ignore))
        {
            return;
        }

        Vector3 forward = playerRoot.forward;
        if (foot != null && foot.forward.sqrMagnitude > 0.001f)
            forward = foot.forward;

        sandInteraction.QueueFootprint(
            hit.point + hit.normal * 0.005f,
            forward,
            footprintSize,
            footprintStrength
        );

        if (dustEmitter != null)
            dustEmitter.EmitAt(hit.point + hit.normal * 0.01f, forward, hit.normal);

        nextLeft = !nextLeft;
    }

    private Transform GetNextFoot()
    {
        if (leftFoot == null && rightFoot == null)
            return null;

        if (nextLeft && leftFoot != null)
            return leftFoot;

        if (!nextLeft && rightFoot != null)
            return rightFoot;

        return leftFoot != null ? leftFoot : rightFoot;
    }
}
