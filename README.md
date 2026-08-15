# terraform-mcpg

Opinionated Terraform / OpenTofu modules that install the MCPG Kubernetes
operator and manage a gateway fleet as declarative infrastructure — CRDs, trust,
plugin catalogue, gateways, coordination backends, routes and multi-tenant
fan-out. Every module targets **Terraform ≥ 1.7** or **OpenTofu ≥ 1.7**; the
same source tree runs under either CLI.

## Prerequisites

- A Kubernetes cluster and a kubeconfig.
- Providers: `hashicorp/kubernetes` (≥ 2.30), `hashicorp/helm` (≥ 2.13) and
  `alekc/kubectl` (≥ 2.0), configured by the calling root module — these modules
  never configure a provider themselves.
- **cert-manager** in the cluster. The operator's admission webhook fails
  closed, so the operator module enables cert-manager webhook TLS by default;
  without it every custom-resource apply blocks. To bring your own TLS, pass
  `cert_manager = { enabled = false }` together with a `webhook` Secret config.
- Network access to the operator Helm chart and the gateway image, or a mirror
  of both (see the `airgap` module and example).

## Quick start

The root module wires the common case in one call: CRDs, the operator, the
cluster-default revocation list, and optionally one plugin set plus one gateway.

```hcl
module "mcpg" {
  source = "./terraform-mcpg" # wherever you vendored this module suite

  operator_chart_version = "<version>" # pin the operator chart; never float
  namespace              = "mcpg-system"

  gateway = {
    name  = "orders"
    image = { repository = "ghcr.io/mcpg-dev/source-code/gateway", tag = "<version>" }
    governance = {
      audit = { sinks = [{ kind = "dev.mcpg.builtin.audit.local-file" }] }
    }
  }
}
```

Compose the submodules directly for anything more bespoke:

```hcl
module "crds" {
  source = "./modules/crds" # CRDs ship inside the module; point crds_dir elsewhere to override
}

module "operator" {
  source        = "./modules/operator"
  chart_version = "<version>"
  depends_on    = [module.crds]
}

module "gateway" {
  source     = "./modules/gateway"
  name       = "orders"
  namespace  = "mcpg-system"
  image      = { repository = "ghcr.io/mcpg-dev/source-code/gateway", tag = "<version>" }
  governance = { audit = { sinks = [{ kind = "dev.mcpg.builtin.audit.local-file" }] } }
  depends_on = [module.operator]
}
```

## Modules

| Module | Renders |
|---|---|
| `modules/crds` | the `mcpg.dev` CRDs as individually server-side-applied resources, so a schema change is an ordinary `apply` rather than a Helm-skipped upgrade |
| `modules/operator` | the operator Helm release with `crd.install=false`, a `small`/`medium`/`large` sizing preset, and cert-manager or bring-your-own webhook TLS |
| `modules/gateway` | an `MCPGGateway` plus the **config builder** — typed `server` / `governance` / `observability` / `mcp` / `plugins` sections merged with an `extra_config` escape hatch |
| `modules/plugin` | one `MCPGPlugin` catalogue entry (`plugin_id`, `plugin_class`, `plugin_version`, `oci`, `trust` — `version` is a reserved module argument, hence `plugin_version`) |
| `modules/plugin-set` | an `MCPGPluginSet`: ordered entries plus a `capabilityGrants` map keyed by entry id |
| `modules/trust-bootstrap` | the `cluster-default` `MCPGRevocationList` and a pass-through of the signing-key `secretRef` |
| `modules/cluster` | an `MCPGCluster` coordination backend (`single_node`, `redis`, `nats`, `consul`, `etcd`), optionally creating the backend credential Secrets it exposes as `cred://cluster/<name>` |
| `modules/route` | an `MCPGRoute` — the soft-multi-tenancy primitive binding a tool subset into a shared gateway with identity / policy / audit chains |
| `modules/tenant-cr` | an `MCPGTenant`: the declarative governance boundary (plugin allowlist, quotas, exclusive namespace ownership) |
| `modules/tenant` | one tenant as an imperative fan-out — namespace, RBAC, NetworkPolicy, and optionally a plugin set and gateway; call with `for_each` over a tenant map |
| `modules/plugin-mirror` | an `MCPGPluginMirror` — the in-cluster OCI mirror that rehomes upstream plugin references |
| `modules/airgap` | the air-gap profile: the mirror plus the outputs the plugin and image references need — `mirror_name` for a plugin's `oci.mirrorRef`, `mirror_host` for direct image pulls |
| `modules/observability` | a pure input/output helper that assembles the gateway `monitoring` block (ServiceMonitor / PrometheusRule toggles) |

`modules/tenant` and `modules/tenant-cr` are complementary, not alternatives:
the first creates the namespace and network isolation, the second is the CR that
makes the operator enforce the plugin allowlist and quotas. Use either or both.

## OpenTofu

OpenTofu runs these modules unmodified. OpenTofu-only features ship as `.tofu`
overlay files beside the `.tf` baseline — a `.tofu` file is loaded by `tofu` and
ignored by `terraform`, so one source tree stays valid for both CLIs.
`examples/single-gateway/encryption.tofu` is the worked case: it encrypts state
and plan at rest with a PBKDF2 key provider, which you swap for a KMS key
provider in production.

## Parameters

### Root module inputs

| Parameter | Description | Default |
|---|---|---|
| `operator_chart_version` | Pinned operator chart version. Required — never float. | — |
| `namespace` | Namespace for the operator and gateway. | `"mcpg-system"` |
| `crds_dir` | Directory of split-by-kind CRD YAMLs. Null uses the CRDs vendored into `modules/crds`. | `null` |
| `sizing_preset` | Operator sizing: `small`, `medium` or `large`. | `"medium"` |
| `cert_manager` | cert-manager webhook TLS (chart `certManager` values). Null enables cert-manager automatically unless `webhook` is set. | `null` |
| `webhook` | Pre-provisioned webhook TLS config (chart `webhook` values). Setting it disables the cert-manager default. | `null` |
| `watch_namespace` | Restrict the operator to one namespace. Null watches all. | `null` |
| `operator_values` | Extra operator chart values, deep-merged last. | `{}` |
| `bootstrap_trust` | Seed the cluster-default `MCPGRevocationList`. | `true` |
| `plugin_set` | Optional plugin set: `{ name?, entries, capability_grants? }`. | `null` |
| `gateway` | Optional gateway: `{ name, image, replicas?, governance?, plugins?, extra_config? }`. | `null` |

### Gateway module inputs

`modules/gateway` splits into config-builder inputs, which land inside
`spec.config` (the gateway's own application config), and wrapper inputs, which
are CRD `spec` fields.

| Parameter | Description | Default |
|---|---|---|
| `name`, `namespace`, `image` | Gateway identity and image. Required by the CRD. | — |
| `server` | Listener config. Emitted at `config.gateway.server`, not as a top-level `server` key. | `null` |
| `governance` | `config.governance` — access, policy, approvals, audit. Audit sinks are a list: `{ audit = { sinks = [{ kind = "…" }] } }`. | `null` |
| `observability` | `config.observability`. | `null` |
| `mcp` | `config.mcp` (capabilities and related settings). | `null` |
| `plugins` | Ordered `config.plugins` list. Each entry needs an `id` and a `source` with exactly one of `path` / `oci`; the per-entry toggle is `disabled`, not `enabled`. | `[]` |
| `extra_config` | Arbitrary config fragment deep-merged **last** into `spec.config`, so no field is unreachable. | `{}` |
| `replicas`, `resources`, `service`, `ingress`, `autoscaling`, `monitoring`, `network_policy`, `pod_disruption_budget`, `workload_identity`, `scheduling`, `probes`, `image_pull_secrets`, `pod_annotations`, `pod_labels` | CRD `spec` blocks, emitted only when set. | `null` |
| `plugin_set_ref`, `revocation_list_ref`, `cluster_ref` | Names of an `MCPGPluginSet`, `MCPGRevocationList` and `MCPGCluster` to bind. | `null` |
| `accepted_route_namespaces` | Namespaces whose `MCPGRoute`s this gateway accepts. Null accepts the gateway's own namespace only. | `null` |
| `extra_spec` | Arbitrary `spec`-level fields merged last. | `{}` |
| `wait` | Wait for the CR to be applied and accepted. This does not block on the operator's `Ready` condition. | `true` |

### Outputs

The root module exposes `operator_namespace`, `operator_values` (the merged
chart values, useful for asserting a preset landed), `gateway_name`,
`gateway_manifest`, `plugin_set_name` and `crd_kinds`. `modules/gateway`
additionally exposes `config_fingerprint`, a client-side SHA-256 of the rendered
`spec.config` that changes whenever the built config changes.

## Examples

| Example | What it stands up |
|---|---|
| [`examples/single-gateway`](examples/single-gateway) | CRDs, operator and one gateway — the smallest complete install, plus the state-encryption overlay |
| [`examples/multi-tenant`](examples/multi-tenant) | cluster trust plus a namespace, RBAC, NetworkPolicy, plugin set and gateway per entry in a `tenants` map |
| [`examples/governance`](examples/governance) | a coordination backend, a shared gateway bound to it, an `MCPGTenant` boundary and a tenant-scoped `MCPGRoute` |
| [`examples/airgap`](examples/airgap) | an in-cluster OCI mirror and a digest-pinned plugin pulled from it, with no public-registry references |
| [`examples/hybrid-gitops`](examples/hybrid-gitops) | Terraform owning CRDs, operator, trust and namespaces while a GitOps controller owns the gateway CRs, with handoff outputs and no drift loop |

## Commands

From `iac/terraform`, the same checks CI runs:

```bash
tofu fmt -check -recursive && tflint --recursive   # lint
tofu init -backend=false && tofu validate          # validate
tofu test                                          # offline, mock providers
```

And from the repo root, `bash iac/codegen/snapshot-schemas.sh` refreshes the
CRD schema snapshot.

The bundle vendors the CRD snapshot into `modules/crds/crds/`, so a consumer of
the published module needs neither this repository's codegen tree nor a live
cluster to run `init`.

## Licence

Apache-2.0.

## See also

- <https://mcpg.dev/docs/self-hosting/terraform> — the full install guide for
  this module suite.
- <https://mcpg.dev/docs/self-hosting/opentofu> — OpenTofu specifics, including
  state encryption.
- <https://mcpg.dev/docs/self-hosting/terraform-provider> — the native provider,
  which adds plan-time validation mirroring the operator's admission webhook.
- <https://mcpg.dev/docs/reference/operator-crds> — the `mcpg.dev` CRDs these
  modules render.
- <https://mcpg.dev/docs/reference/configuration> — the gateway configuration
  schema the config builder assembles.

## Working with the module

```sh
terraform init
terraform validate
terraform fmt -check -recursive
```
