# User-Defined Networks (UDN) for Zero Trust Network Isolation

## Overview

User-Defined Networks (UDN) provide layer 2/3 network isolation for workloads in OpenShift, separate from the default cluster network. This feature implements Zero Trust network segmentation principles by creating an isolated network for the qtodo application, restricting communication to only necessary services.

## Architecture

### Network Topology

The UDN implementation creates a dedicated isolated network for qtodo workloads:

```text
┌─────────────────────────────────────────────────────────────┐
│                      Cluster Network                         │
│  ┌────────────┐    ┌─────────┐    ┌──────────┐             │
│  │  Router    │───▶│ qtodo   │───▶│ Vault    │             │
│  │  (Ingress) │    │ (eth0)  │    │ (8200)   │             │
│  └────────────┘    └────┬────┘    └──────────┘             │
│                         │                                    │
│                         │ UDN Attachment                     │
└─────────────────────────┼──────────────────────────────────┘
                          │
                    ┌─────▼──────┐
                    │    UDN     │
                    │ (net1/     │
                    │  Layer2)   │
                    └─────┬──────┘
                          │
                ┌─────────┴─────────┐
                │                   │
          ┌─────▼──────┐      ┌────▼─────┐
          │ qtodo pod  │      │ qtodo-db │
          │ (isolated) │──────│  (5432)  │
          └────────────┘      └──────────┘
               │
               └─────────▶ DNS (5353) via cluster network
```

### Dual Network Interfaces

When UDN is enabled, qtodo pods have two network interfaces:

1. **eth0 (Primary - Cluster Network)**
   - Ingress from OpenShift Router (port 8080)
   - Egress to Vault (SPIFFE auth, port 8200)
   - Egress to Keycloak (OIDC back-channel, port 443)
   - DNS resolution (CoreDNS, port 5353)

2. **net1 (Secondary - UDN)**
   - PostgreSQL communication (qtodo ↔ qtodo-db, port 5432)
   - Isolated from other cluster workloads
   - Layer 2 topology (same subnet across nodes)

## Security Benefits

1. **Network Segmentation**: qtodo workloads are isolated from arbitrary cluster traffic
2. **Explicit Allow-Lists**: AdminNetworkPolicy enforces allow-only-required communication
3. **Defense in Depth**: Combines with existing NetworkPolicy for dual-layer protection
4. **Blast Radius Reduction**: Compromise of qtodo cannot pivot to unrelated services
5. **Compliance**: Supports Zero Trust architecture mandates (NIST 800-207)

## Components

UDN is integrated into the qtodo Helm chart (`charts/qtodo`). When enabled, the following resources are created:

### UserDefinedNetwork CR

Template: `charts/qtodo/templates/udn-user-defined-network.yaml`

Creates the isolated network with Layer2 topology:

- Subnet: `10.100.0.0/16`
- MTU: 1400 (avoids fragmentation)
- IPAM: Persistent IP assignment
- Sync-wave: 35 (before NAD)

### NetworkAttachmentDefinition

Template: `charts/qtodo/templates/udn-network-attachment-definition.yaml`

Defines how pods attach to the UDN:

- CNI type: `ovn-k8s-cni-overlay`
- References the UserDefinedNetwork
- Used via pod annotation `k8s.v1.cni.cncf.io/networks`
- Sync-wave: 36 (before policies)

### AdminNetworkPolicy

Template: `charts/qtodo/templates/udn-admin-network-policy.yaml`

Explicit allow-list for UDN traffic:

- **Ingress**:
  - OpenShift router (port 8080)
  - qtodo pods to qtodo-db (port 5432)
- **Egress**: DNS, PostgreSQL, Vault, Keycloak OIDC
- Priority: 50 (higher = processed first)
- Sync-wave: 37 (before qtodo app)

## Enabling UDN

### Option 1: Feature Variant Generator (Recommended)

```bash
python3 scripts/gen-feature-variants.py \
  --features udn \
  --base values-hub.yaml \
  --outdir /tmp

# Review the generated variant
diff values-hub.yaml /tmp/values-hub-udn.yaml

# Apply the variant
cp /tmp/values-hub-udn.yaml values-hub.yaml
./pattern.sh make install
```

### Option 2: Manual Configuration

1. **Enable UDN in the qtodo application** in `values-hub.yaml`:

   ```yaml
   clusterGroup:
     applications:
       qtodo:
         # ... existing config ...
         overrides:
           # ... existing overrides ...
           - name: app.udn.enabled
             value: "true"
   ```

2. **Deploy**:

   ```bash
   ./pattern.sh make install
   ```

## Verification

### 1. Check UDN Resources

```bash
# UserDefinedNetwork
oc get userdefinednetwork -n qtodo
NAME                      AGE
qtodo-isolated-network    5m

# NetworkAttachmentDefinition
oc get network-attachment-definitions -n qtodo
NAME            AGE
qtodo-udn-nad   5m
```

### 2. Verify Network Policies

```bash
# AdminNetworkPolicy
oc get adminnetworkpolicy
NAME              PRIORITY   AGE
qtodo-udn-policy  50         5m
```

### 3. Inspect Pod Network Interfaces

qtodo pods should have two interfaces: `eth0` (cluster) and `net1` (UDN).

```bash
# Check qtodo pod
POD=$(oc get pod -n qtodo -l app=qtodo -o name | head -1)
oc exec -n qtodo $POD -- ip addr show

# Expected output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> ...
# 3: eth0@if...: <BROADCAST,MULTICAST,UP,LOWER_UP> ...  # Cluster network
#     inet 10.128.2.45/23 ...
# 4: net1@if...: <BROADCAST,MULTICAST,UP,LOWER_UP> ...  # UDN
#     inet 10.100.0.15/16 ...
```

### 4. Test Connectivity

```bash
# DNS resolution (should work via eth0)
oc exec -n qtodo $POD -- nslookup qtodo-db

# PostgreSQL connectivity (should work via net1)
oc exec -n qtodo $POD -- nc -zv qtodo-db 5432

# Vault API (should work via eth0)
oc exec -n qtodo $POD -- curl -k https://vault.vault.svc:8200/v1/sys/health
```

### 5. Verify qtodo Application

```bash
# Get the route
QTODO_URL=$(oc get route -n qtodo qtodo -o jsonpath='{.spec.host}')

# Access the application
curl https://$QTODO_URL
```

## Configuration Options

UDN is configured via the `app.udn` section in `charts/qtodo/values.yaml`:

| Parameter                        | Description                      | Default                  |
| -------------------------------- | -------------------------------- | ------------------------ |
| `app.udn.enabled`                | Enable UDN                       | `false`                  |
| `app.udn.name`                   | UserDefinedNetwork name          | `qtodo-isolated-network` |
| `app.udn.nadName`                | NetworkAttachmentDefinition name | `qtodo-udn-nad`          |
| `app.udn.topology`               | Network topology (Layer2/Layer3) | `Layer2`                 |
| `app.udn.subnet`                 | CIDR for UDN                     | `10.100.0.0/16`          |
| `app.udn.mtu`                    | MTU for the network              | `1400`                   |
| `app.udn.networkPolicy.enabled`  | Enable AdminNetworkPolicy        | `true`                   |

### Layer3 Topology

For larger deployments, Layer3 provides better scalability. Override in `values-hub.yaml`:

```yaml
clusterGroup:
  applications:
    qtodo:
      overrides:
        - name: app.udn.enabled
          value: "true"
        - name: app.udn.topology
          value: "Layer3"
        - name: app.udn.joinSubnet
          value: "100.64.0.0/16"
```

## Troubleshooting

### Pod Fails to Start

**Symptom**: Pod stuck in `ContainerCreating` with network errors.

**Check**:

```bash
oc describe pod -n qtodo <pod-name>
```

**Solution**:

- Verify UDN and NAD exist: `oc get userdefinednetwork,nad -n qtodo`
- Check sync-wave ordering: UDN (35) → NAD (36) → Policies (37) → qtodo app (38)

### Network Connectivity Issues

**Symptom**: qtodo cannot reach PostgreSQL/Vault/Keycloak.

**Check AdminNetworkPolicy**:

```bash
oc get adminnetworkpolicy qtodo-udn-policy -o yaml
```

**Debug**:

```bash
# Check which interface is being used
oc exec -n qtodo $POD -- ip route get <target-ip>

# Capture traffic on UDN interface
oc exec -n qtodo $POD -- tcpdump -i net1 -n
```

### UDN Resource Not Found

**Symptom**: `UserDefinedNetwork` CRD not available.

**Solution**: Requires OpenShift 4.14+ with OVN-Kubernetes. Check:

```bash
oc get crd userdefinednetworks.k8s.ovn.org
```

## Disabling UDN

To revert to cluster network only:

```bash
# Option 1: Use feature variant without UDN
python3 scripts/gen-feature-variants.py --features <other-features> --base values-hub.yaml

# Option 2: Manually disable
# In values-hub.yaml, remove the app.udn.enabled override from qtodo application
./pattern.sh make install
```

The qtodo application will redeploy without the UDN annotation and resources, using only the cluster network.

## Performance Considerations

- **Latency**: UDN adds ~0.1-0.5ms latency for inter-pod communication vs cluster network
- **Throughput**: No significant impact (<5% overhead) for typical workloads
- **Resource Usage**: Minimal (~10MB memory per node for OVN-Kubernetes UDN management)

## Security Considerations

### Defense in Depth

UDN complements, but does not replace, other security controls:

- **NetworkPolicy**: Still applied on the cluster network (eth0)
- **Service Mesh**: mTLS can layer on top of UDN
- **ACS Policies**: Runtime enforcement still active

### Attack Surface

- UDN pods are still reachable via cluster network (eth0) for ingress/egress to external services
- AdminNetworkPolicy must be correctly configured to avoid bypasses
- Pods with CAP_NET_ADMIN could potentially manipulate interfaces

## References

- [OpenShift UDN Documentation](https://docs.openshift.com/container-platform/latest/networking/multiple_networks/about-user-defined-networks.html)
- [OVN-Kubernetes User-Defined Networks](https://github.com/ovn-org/ovn-kubernetes/blob/master/docs/user-defined-networks.md)
- [AdminNetworkPolicy API](https://network-policy-api.sigs.k8s.io/reference/admin-network-policy/)
- [NIST SP 800-207 Zero Trust Architecture](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf)
