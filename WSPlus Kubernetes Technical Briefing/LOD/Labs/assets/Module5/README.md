# Module 5 – GitOps Demo Assets

These manifests are designed to be **copied into a Git repository you control** (a fork of the Microsoft sample repo, or a fresh repo) so Flux can reconcile them onto your AKS cluster.

| File | Purpose |
| --- | --- |
| `sample-app.yaml` | A small `podinfo` Deployment + Service in a `gitops-demo` namespace. Use it to demonstrate adding a new workload via GitOps. |
| `kustomization.yaml` | A minimal Kustomize entry point so Flux can reconcile a folder containing `sample-app.yaml`. |

## Suggested layout in your fork

```
my-gitops-repo/
├── infrastructure/
│   └── ...                  # cluster-wide infra (ingress, monitoring, etc.)
└── apps/
    └── staging/
        ├── kustomization.yaml
        └── sample-app.yaml
```

Point the `apps` Flux Kustomization at `./apps/staging` and the workload will appear in the cluster automatically.
